defmodule ClaperWeb.StatController do
  use ClaperWeb, :controller

  alias Claper.Forms

  def export(conn, %{"form_id" => form_id}) do
    form = Forms.get_form!(form_id, [:form_submits])
    headers = form.fields |> Enum.map(& &1.name)
    csv_data = headers |> csv_content(form.form_submits |> Enum.map(& &1.response))

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{form.title}.csv\"")
    |> put_root_layout(false)
    |> send_resp(200, csv_data)
  end

  defp csv_content(headers, records) do
    data =
      records
      |> Enum.map(&(&1 |> Map.values()))

    ([headers] ++ data)
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end
end
