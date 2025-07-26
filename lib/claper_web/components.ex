defmodule ClaperWeb.Components do
  @moduledoc """
  Provides UI components for the Claper application.

  ## Usage

  Import this module in your views or live views:

      import ClaperWeb.Components
      
  Then use the components:

      <.input id="email" name="email" type="email" placeholder="Enter your email" />
      <.button variant="primary">Submit</.button>
      <.ui_label for="email">Email Address</.ui_label>
  """

  defdelegate input(assigns), to: ClaperWeb.Components.Input
  defdelegate button(assigns), to: ClaperWeb.Components.Button
  defdelegate ui_label(assigns), to: ClaperWeb.Components.Label, as: :label
end
