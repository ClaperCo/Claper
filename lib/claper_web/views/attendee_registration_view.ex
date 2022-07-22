defmodule ClaperWeb.AttendeeRegistrationView do
  use ClaperWeb, :view

  def render("attendee.json", %{attendee: attendee, token: token}) do
    %{
      name: attendee.name,
      avatar: attendee.avatar,
      token: token
    }
  end
end
