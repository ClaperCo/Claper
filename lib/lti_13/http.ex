defmodule Lti13.HTTP do
  @moduledoc """
  HTTPS requests to untrusted LTI platforms.

  Resolves and checks every destination before connecting to the checked IP,
  retaining the original hostname for TLS verification and the Host header.
  Redirects are deliberately not followed: they must not bypass destination
  checks or forward platform credentials to a different origin.
  """

  import Bitwise

  # Platform documents (OpenID configuration, JWKS, AGS/NRPS pages) are small;
  # an unbounded body would let a hostile platform exhaust memory.
  @max_body_bytes 1_048_576

  @blocked_ipv4 [
    {{0, 0, 0, 0}, 8},
    {{10, 0, 0, 0}, 8},
    {{100, 64, 0, 0}, 10},
    {{127, 0, 0, 0}, 8},
    {{168, 63, 129, 16}, 32},
    {{169, 254, 0, 0}, 16},
    {{172, 16, 0, 0}, 12},
    {{192, 0, 0, 0}, 24},
    {{192, 0, 2, 0}, 24},
    {{192, 88, 99, 0}, 24},
    {{192, 168, 0, 0}, 16},
    {{198, 18, 0, 0}, 15},
    {{198, 51, 100, 0}, 24},
    {{203, 0, 113, 0}, 24},
    {{224, 0, 0, 0}, 3}
  ]

  def get(url, options \\ []), do: request(:get, url, options)
  def post(url, options \\ []), do: request(:post, url, options)
  def put(url, options \\ []), do: request(:put, url, options)

  @doc """
  Checks URL syntax and public DNS answers without making an HTTP request.
  """
  def validate_url(url) do
    with :ok <- ensure_enabled(),
         {:ok, _uri, _address} <- destination(url),
         do: :ok
  end

  defp request(method, url, options) do
    with :ok <- ensure_enabled(),
         {:ok, uri, address} <- destination(url) do
      # A numeric destination cannot be rebound between validation and connect.
      # :hostname keeps SNI and certificate verification bound to the LMS name.
      pinned_uri = %{uri | host: address |> :inet.ntoa() |> to_string(), authority: nil}
      hostname = if String.contains?(uri.host, ":"), do: "[#{uri.host}]", else: uri.host
      host = if uri.port == 443, do: hostname, else: "#{hostname}:#{uri.port}"

      options =
        Application.get_env(:claper, :lti_http_req, [])
        |> Keyword.merge(options)
        |> Keyword.merge(
          method: method,
          url: pinned_uri,
          redirect: false,
          retry: false,
          adapter: &send_request(&1, address, uri.host),
          receive_timeout: 10_000
        )

      options
      |> Req.new()
      |> Req.Request.put_header("host", host)
      |> Req.request()
    end
  end

  defp ensure_enabled do
    if Claper.Settings.lti_enabled?(), do: :ok, else: {:error, :lti_disabled}
  end

  # Use a single short-lived Mint connection. Req's dynamic Finch pools create
  # permanent atoms per connection configuration; untrusted hostnames must not
  # become permanent pool names. The IP tuple prevents a second DNS lookup.
  defp send_request(request, address, hostname) do
    case Mint.HTTP.connect(:https, address, request.url.port,
           hostname: hostname,
           protocols: [:http1],
           mode: :passive,
           transport_opts: [timeout: 5_000]
         ) do
      {:ok, conn} ->
        try do
          {request, exchange(conn, request)}
        after
          Mint.HTTP.close(conn)
        end

      {:error, error} ->
        {request, error}
    end
  end

  defp exchange(conn, request) do
    headers = for {name, values} <- request.headers, value <- values, do: {name, value}
    path = request.url.path || "/"
    path = if request.url.query, do: path <> "?" <> request.url.query, else: path
    method = request.method |> Atom.to_string() |> String.upcase()

    case Mint.HTTP.request(conn, method, path, headers, request.body) do
      {:ok, conn, ref} ->
        deadline = System.monotonic_time(:millisecond) + 10_000
        receive_response(conn, ref, Req.Response.new(), {[], 0}, deadline)

      {:error, _conn, error} ->
        error
    end
  end

  defp receive_response(conn, ref, response, chunks, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    case Mint.HTTP.recv(conn, 0, remaining) do
      {:ok, conn, events} ->
        case Enum.reduce_while(events, {response, chunks}, &consume_response_event/2) do
          {:done, response} -> response
          {:error, error} -> error
          {response, chunks} -> receive_response(conn, ref, response, chunks, deadline)
        end

      {:error, _conn, error, _events} ->
        error
    end
  end

  defp consume_response_event({:status, _ref, status}, {response, chunks}) do
    {:cont, {%{response | status: status}, chunks}}
  end

  defp consume_response_event({:headers, _ref, headers}, {response, chunks}) do
    fields = Req.Response.new(headers: headers).headers
    fields = Map.merge(response.headers, fields, fn _name, old, new -> old ++ new end)
    {:cont, {%{response | headers: fields}, chunks}}
  end

  defp consume_response_event({:data, _ref, chunk}, {response, {chunks, size}}) do
    size = size + byte_size(chunk)

    if size > @max_body_bytes do
      {:halt, {:error, %Req.TransportError{reason: :response_too_large}}}
    else
      {:cont, {response, {[chunk | chunks], size}}}
    end
  end

  defp consume_response_event({:done, _ref}, {response, {chunks, _size}}) do
    body = chunks |> Enum.reverse() |> IO.iodata_to_binary()
    {:halt, {:done, %{response | body: body}}}
  end

  defp destination(url) when is_binary(url) do
    with {:ok, %URI{scheme: "https", host: host, userinfo: nil, fragment: nil} = uri} <-
           URI.new(url),
         true <- is_binary(host) and host != "" and uri.port in 1..65_535,
         {:ok, addresses} <- resolve(host),
         true <- addresses != [] and Enum.all?(addresses, &public_address?/1) do
      {:ok, uri, hd(addresses)}
    else
      _ -> {:error, :unsafe_lti_url}
    end
  end

  defp destination(_url), do: {:error, :unsafe_lti_url}

  defp resolve(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} ->
        {:ok, [address]}

      {:error, _} ->
        resolve_hostname(host)
    end
  end

  defp resolve_hostname(host) do
    resolver = Application.get_env(:claper, :lti_http_resolver, &:inet.getaddrs/3)
    hostname = String.to_charlist(host)

    results = Enum.map([:inet, :inet6], &resolver.(hostname, &1, 5_000))

    if Enum.all?(results, fn
         {:ok, _addresses} -> true
         {:error, reason} when reason in [:nxdomain, :einval] -> true
         _ -> false
       end) do
      {:ok,
       Enum.flat_map(results, fn
         {:ok, addresses} -> addresses
         _ -> []
       end)}
    else
      {:error, :unresolvable_lti_host}
    end
  end

  defp public_address?({a, b, c, d} = address)
       when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 do
    number = ipv4_number(address)

    not Enum.any?(@blocked_ipv4, fn {network, bits} ->
      number >>> (32 - bits) == ipv4_number(network) >>> (32 - bits)
    end)
  end

  # Only globally routable IPv6 unicast. Exclude protocol assignments, 6to4,
  # and documentation ranges, including every IPv4-mapped/translation address.
  defp public_address?({a, b, _c, _d, _e, _f, _g, _h}) do
    a in 0x2000..0x3FFF and
      not (a == 0x2001 and (b < 0x0200 or b == 0x0DB8)) and
      a != 0x2002 and not (a == 0x3FFF and b < 0x1000)
  end

  defp public_address?(_address), do: false

  defp ipv4_number({a, b, c, d}), do: a <<< 24 ||| b <<< 16 ||| c <<< 8 ||| d
end
