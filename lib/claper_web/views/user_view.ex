defmodule ClaperWeb.UserView do
  use ClaperWeb, :view

  def render("user.json", %{user: user}) do
    %{
      uuid: user.uuid,
      email: user.email
    }
  end
end
