defmodule ClaperWeb.UserRegistrationView do
  import Phoenix.Component
  use ClaperWeb, :view

  def render("user.json", %{user_registration: user}) do
    %{
      email: user.email,
      name: user.full_name
    }
  end
end
