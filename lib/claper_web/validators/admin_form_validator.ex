defmodule ClaperWeb.Validators.AdminFormValidator do
  @moduledoc """
  Provides validation functions for admin panel forms.
  
  This module contains helper functions to validate input data
  for admin forms before processing, providing consistent validation
  across the admin panel.
  """
  
  @doc """
  Validates OIDC provider data.
  
  Returns {:ok, validated_params} or {:error, errors}
  """
  def validate_oidc_provider(params) do
    errors = []
    
    errors =
      if String.trim(params["name"]) == "" do
        [{:name, "Name cannot be blank"} | errors]
      else
        errors
      end
      
    errors =
      if !is_valid_url?(params["issuer"]) do
        [{:issuer, "Issuer must be a valid URL"} | errors]
      else
        errors
      end
      
    errors =
      if String.trim(params["client_id"]) == "" do
        [{:client_id, "Client ID cannot be blank"} | errors]
      else
        errors
      end
      
    errors =
      if String.trim(params["client_secret"]) == "" do
        [{:client_secret, "Client Secret cannot be blank"} | errors]
      else
        errors
      end
      
    if Enum.empty?(errors) do
      {:ok, params}
    else
      {:error, errors}
    end
  end
  
  @doc """
  Validates event data.
  
  Returns {:ok, validated_params} or {:error, errors}
  """
  def validate_event(params) do
    errors = []
    
    errors =
      if String.trim(params["name"]) == "" do
        [{:name, "Name cannot be blank"} | errors]
      else
        errors
      end
      
    errors =
      if String.trim(params["code"]) == "" do
        [{:code, "Code cannot be blank"} | errors]
      else
        errors
      end
      
    if Enum.empty?(errors) do
      {:ok, params}
    else
      {:error, errors}
    end
  end
  
  @doc """
  Validates user data.
  
  Returns {:ok, validated_params} or {:error, errors}
  """
  def validate_user(params) do
    errors = []
    
    errors =
      if String.trim(params["email"]) == "" do
        [{:email, "Email cannot be blank"} | errors]
      else
        if !is_valid_email?(params["email"]) do
          [{:email, "Email is not valid"} | errors]
        else
          errors
        end
      end
      
    if Enum.empty?(errors) do
      {:ok, params}
    else
      {:error, errors}
    end
  end
  
  # Private helper functions
  
  defp is_valid_url?(nil), do: false
  defp is_valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme != nil && uri.host != nil && uri.host =~ "."
  end
  
  defp is_valid_email?(nil), do: false
  defp is_valid_email?(email) do
    Regex.match?(~r/^[^\s]+@[^\s]+\.[^\s]+$/, email)
  end
end
