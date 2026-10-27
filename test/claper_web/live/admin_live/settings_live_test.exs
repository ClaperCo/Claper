defmodule ClaperWeb.AdminLive.SettingsLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures

  alias Claper.Accounts
  alias Claper.Settings

  test "a demoted administrator cannot enable LTI from an open settings page", %{conn: conn} do
    for name <- ["user", "admin"] do
      _ = Accounts.get_role_by_name(name) || elem(Accounts.create_role(%{name: name}), 1)
    end

    user = confirmed_user_fixture()
    {:ok, admin} = Accounts.assign_role(user, "admin")
    {:ok, view, _} = conn |> log_in_user(admin) |> live(~p"/admin/settings")
    {:ok, _} = Settings.set("lti_enabled", "false")
    {:ok, _} = Accounts.assign_role(admin, "user")

    view |> form("#lti-settings-form", %{"lti_enabled" => "true"}) |> render_submit()
    refute Settings.lti_enabled?()
  end

  test "regular users cannot open global settings", %{conn: conn} do
    user = confirmed_user_fixture()
    assert {:error, {:redirect, _}} = conn |> log_in_user(user) |> live(~p"/admin/settings")
  end
end
