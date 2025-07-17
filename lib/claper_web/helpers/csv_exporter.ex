defmodule ClaperWeb.Helpers.CSVExporter do
  @moduledoc """
  Helper module for exporting data to CSV format.

  This module provides functions to convert collections of data
  into CSV format for download in the admin panel.
  """

  @doc """
  Converts a list of records to CSV format.

  ## Parameters
    - records: List of records/maps to convert
    - headers: List of column headers
    - fields: List of fields to include in the CSV

  ## Returns
    - CSV formatted string
  """
  def to_csv(records, headers, fields) do
    records
    |> build_rows(fields)
    |> add_headers(headers)
    |> CSV.encode()
    |> Enum.to_list()
    |> Enum.join("")
  end

  @doc """
  Generates a timestamped filename for CSV exports.

  ## Parameters
    - prefix: Prefix for the filename (e.g., "users", "events")

  ## Returns
    - String filename with timestamp
  """
  def generate_filename(prefix) do
    date = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
    "#{prefix}_export_#{date}.csv"
  end

  # Private helper functions

  defp build_rows(records, fields) do
    Enum.map(records, fn record ->
      Enum.map(fields, fn field ->
        format_field_value(Map.get(record, field))
      end)
    end)
  end

  defp add_headers(rows, headers) do
    [headers | rows]
  end

  defp format_field_value(value) when is_boolean(value) do
    if value, do: "Yes", else: "No"
  end

  defp format_field_value(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end

  defp format_field_value(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end

  defp format_field_value(nil), do: ""

  defp format_field_value(value), do: to_string(value)

  @doc """
  Exports a list of users to CSV format.

  ## Parameters
    - users: List of User structs to export

  ## Returns
    - CSV formatted string
  """
  def export_users_to_csv(users) do
    headers = ["Email", "Date Created"]
    fields = [:email, :inserted_at]

    to_csv(users, headers, fields)
  end

  @doc """
  Exports a list of events to CSV format.

  ## Parameters
    - events: List of Event structs to export

  ## Returns
    - CSV formatted string
  """
  def export_events_to_csv(events) do
    headers = ["Name", "Code", "Owner", "Started At", "Expired At", "Audience Peak", "Date Created"]
    fields = [:name, :code, :user_email, :started_at, :expired_at, :audience_peak, :inserted_at]

    to_csv(events, headers, fields)
  end

  @doc """
  Exports a list of OIDC providers to CSV format.

  ## Parameters
    - providers: List of Provider structs to export

  ## Returns
    - CSV formatted string
  """
  def export_oidc_providers_to_csv(providers) do
    headers = ["Name", "Issuer", "Active", "Date Created"]
    fields = [:name, :issuer, :active, :inserted_at]

    to_csv(providers, headers, fields)
  end
end
