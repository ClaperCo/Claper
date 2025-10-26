defmodule Claper.Accounts.Guardian do
  @moduledoc """
  Implementation module for Guardian authentication.
  This module handles JWT token generation and validation for user authentication.
  """

  defmodule Plug do
    @moduledoc """
    Plug helpers for Guardian authentication in tests.
    """

    @doc """
    Sign in a user to a conn.

    ## Parameters
      - conn: The connection
      - user: The user to sign in
      
    ## Returns
      - Updated conn with user signed in
    """
    def sign_in(conn, user) do
      # For tests, we'll just put the user in the conn assigns
      Elixir.Plug.Conn.assign(conn, :current_user, user)
    end
  end
end
