defmodule ClaperWeb.UserRegistrationView do
  use ClaperWeb, :view

  def render("user.json", %{user_registration: user}) do
    %{
      email: user.email,
      name: user.full_name
    }
  end
end
