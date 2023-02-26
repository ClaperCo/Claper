defmodule ClaperWeb.Router do
  use ClaperWeb, :router

  import ClaperWeb.{UserAuth, EventController}

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {ClaperWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
    plug(ClaperWeb.Plugs.Locale)
  end

  pipeline :protect_with_basic_auth do
    plug :basic_auth
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Manage attendee_identifier in requests
  pipeline :attendee_registration do
    plug(:attendee_identifier)
  end

  live_session :attendee do
    scope "/", ClaperWeb do
      pipe_through([:browser, :attendee_registration])

      live("/", EventLive.Join, :index)
      live("/join", EventLive.Join, :join)
      live("/e/:code", EventLive.Show, :show)
    end
  end

  live_session :user,
    root_layout: {ClaperWeb.LayoutView, "user.html"} do
    scope "/", ClaperWeb do
      pipe_through([:browser, :require_authenticated_user])

      post "/export/:form_id", StatController, :export

      live("/events", EventLive.Index, :index)
      live("/events/new", EventLive.Index, :new)
      live("/events/:id/edit", EventLive.Index, :edit)
      live("/events/:id/stats", StatLive.Index, :index)

      live("/users/settings", UserSettingsLive.Show, :show)
      live("/users/settings/edit/password", UserSettingsLive.Show, :edit_password)
      live("/users/settings/edit/email", UserSettingsLive.Show, :edit_email)
      live("/users/settings/edit/avatar", UserSettingsLive.Show, :edit_avatar)
      live("/users/settings/edit/fullname", UserSettingsLive.Show, :edit_full_name)
    end
  end

  live_session :presenter, on_mount: ClaperWeb.UserLiveAuth do
    scope "/", ClaperWeb do
      pipe_through([:browser, :require_authenticated_user])

      live("/e/:code/presenter", EventLive.Presenter, :show)
      live("/e/:code/manage", EventLive.Manage, :show)
      live("/e/:code/manage/add/poll", EventLive.Manage, :add_poll)
      live("/e/:code/manage/edit/poll/:id", EventLive.Manage, :edit_poll)
      live("/e/:code/manage/add/form", EventLive.Manage, :add_form)
      live("/e/:code/manage/edit/form/:id", EventLive.Manage, :edit_form)
    end
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: ClaperWeb.Telemetry)
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev || System.get_env("ENABLE_MAILBOX_ROUTE", "false") == "true" do
    scope "/dev" do
      if System.get_env("MAILBOX_USER") && System.get_env("MAILBOX_PASSWORD") &&
           System.get_env("ENABLE_MAILBOX_ROUTE", "false") == "true" do
        pipe_through [:browser, :protect_with_basic_auth]
      else
        pipe_through [:browser]
      end

      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  ## Authentication routes
  scope "/", ClaperWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    if System.get_env("ENABLE_ACCOUNT_CREATION", "true") == "true" do
      get("/users/register", UserRegistrationController, :new)
      post("/users/register", UserRegistrationController, :create)
    end

    get("/users/register/confirm", UserRegistrationController, :confirm)
    get("/users/log_in", UserSessionController, :new)
    post("/users/log_in", UserSessionController, :create)
    get("/users/magic/:token", UserConfirmationController, :confirm_magic)
    get("/users/reset_password", UserResetPasswordController, :new)
    post("/users/reset_password", UserResetPasswordController, :create)
    get("/users/reset_password/:token", UserResetPasswordController, :edit)
  end

  scope "/", ClaperWeb do
    pipe_through([:browser, :require_authenticated_user])

    post("/events/:uuid/slide.jpg", EventController, :slide_generate)
    get("/users/settings/confirm_email/:token", UserSettingsController, :confirm_email)
  end

  scope "/", ClaperWeb do
    pipe_through([:browser])

    get("/tos", PageController, :tos)
    get("/privacy", PageController, :privacy)

    delete("/users/log_out", UserSessionController, :delete)
    get("/users/confirm", UserConfirmationController, :new)
    post("/users/confirm", UserConfirmationController, :create)
    get("/users/confirm/:token", UserConfirmationController, :edit)
    post("/users/confirm/:token", UserConfirmationController, :update)
  end

  defp basic_auth(conn, _opts) do
    username = System.fetch_env!("MAILBOX_USER")
    password = System.fetch_env!("MAILBOX_PASSWORD")
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end
end
