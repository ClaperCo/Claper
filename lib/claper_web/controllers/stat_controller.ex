defmodule ClaperWeb.StatController do
  use ClaperWeb, :controller

  alias Claper.Forms

  def export(conn, %{"form_id" => form_id}) do
    form = Forms.get_form!(form_id, [:form_submits])
    csv_data = csv_content(form.form_submits |> Enum.map(& &1.response))

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"export.csv\"")
    |> put_root_layout(false)
    |> send_resp(200, csv_data)
  end

  defp csv_content(records) do
    records
    |> Enum.map(fn record ->
      record
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.values()
    end)
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end
end
