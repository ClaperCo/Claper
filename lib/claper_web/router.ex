defmodule ClaperWeb.Router do
  use ClaperWeb, :router

  import ClaperWeb.{UserAuth, EventController}

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ClaperWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
    plug(ClaperWeb.Plugs.Locale)
  end

  pipeline :lti do
    plug(:accepts, ["html", "json"])
    plug(:put_root_layout, html: {ClaperWeb.LayoutView, :root})
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:fetch_current_user)
    plug(ClaperWeb.Plugs.Locale)
  end

  pipeline :protect_mailbox do
    plug ClaperWeb.MailboxGuard
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
      pipe_through([:browser, :attendee_registration, ClaperWeb.Plugs.Iframe])

      live("/", EventLive.Join, :index)
      live("/join", EventLive.Join, :join)
      live("/e/:code", EventLive.Show, :show)
    end
  end

  live_session :user,
    root_layout: {ClaperWeb.LayoutView, :user} do
    scope "/", ClaperWeb do
      pipe_through([:browser, :require_authenticated_user])

      post "/export/forms/:form_id", StatController, :export_form
      post "/export/polls/:poll_id", StatController, :export_poll
      post "/export/stories/:story_id", StatController, :export_story
      post "/export/quizzes/:quiz_id", StatController, :export_quiz
      post "/export/quizzes/:quiz_id/qti", StatController, :export_quiz_qti
      post "/export/:event_id/messages", StatController, :export_all_messages

      live("/events", EventLive.Index, :index)
      live("/events/new", EventLive.Index, :new)
      live("/events/:id/edit", EventLive.Index, :edit)
      live("/events/:id/stats", StatLive.Index, :index)

      live("/users/settings", UserSettingsLive.Show, :show)
      live("/users/settings/edit/password", UserSettingsLive.Show, :edit_password)
      live("/users/settings/edit/email", UserSettingsLive.Show, :edit_email)
      live("/users/settings/set/password", UserSettingsLive.Show, :set_password)
    end
  end

  live_session :presenter, on_mount: ClaperWeb.UserLiveAuth do
    scope "/", ClaperWeb do
      pipe_through([:browser, :require_authenticated_user])

      live("/e/:code/presenter", EventLive.Presenter, :show)
      live("/e/:code/manage", EventLive.Manage, :show)
      live("/e/:code/manage/add/poll", EventLive.Manage, :add_poll)
      live("/e/:code/manage/edit/poll/:id", EventLive.Manage, :edit_poll)
      live("/e/:code/manage/add/story", EventLive.Manage, :add_story)
      live("/e/:code/manage/edit/story/:id", EventLive.Manage, :edit_story)
      live("/e/:code/manage/add/form", EventLive.Manage, :add_form)
      live("/e/:code/manage/import", EventLive.Manage, :import)
      live("/e/:code/manage/edit/form/:id", EventLive.Manage, :edit_form)
      live("/e/:code/manage/add/embed", EventLive.Manage, :add_embed)
      live("/e/:code/manage/edit/embed/:id", EventLive.Manage, :edit_embed)
      live("/e/:code/manage/add/quiz", EventLive.Manage, :add_quiz)
      live("/e/:code/manage/edit/quiz/:id", EventLive.Manage, :edit_quiz)
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
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:browser, :protect_mailbox]
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  ## Authentication routes
  scope "/", ClaperWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    get("/users/register", UserRegistrationController, :new)
    post("/users/register", UserRegistrationController, :create)

    get("/users/register/confirm", UserRegistrationController, :confirm)
    get("/users/log_in", UserSessionController, :new)
    post("/users/log_in", UserSessionController, :create)
    get("/users/magic/:token", UserConfirmationController, :confirm_magic)
    get("/users/reset_password", UserResetPasswordController, :new)
    post("/users/reset_password", UserResetPasswordController, :create)
    get("/users/reset_password/:token", UserResetPasswordController, :edit)
    post("/users/reset_password/:token", UserResetPasswordController, :update)

    get("/users/confirm", UserConfirmationController, :new)
    post("/users/confirm", UserConfirmationController, :create)
    get("/users/confirm/:token", UserConfirmationController, :update)

    get("/users/oidc", UserOidcAuth, :new)
    get("/users/oidc/callback", UserOidcAuth, :callback)
  end

  scope "/", ClaperWeb do
    pipe_through([:lti])

    get("/.well-known/jwks.json", Lti.RegistrationController, :jwks)
    get("/lti/register", Lti.RegistrationController, :new)
    post("/lti/register", Lti.RegistrationController, :create)
    post("/lti/login", Lti.LaunchController, :login)
    get("/lti/login", Lti.LaunchController, :login)
    post("/lti/launch", Lti.LaunchController, :launch)
  end

  scope "/", ClaperWeb do
    pipe_through([:browser, :require_authenticated_user])

    post("/events/:uuid/slide.jpg", EventController, :slide_generate)
    get("/users/settings/confirm_email/:token", UserSettingsController, :confirm_email)
    delete("/users/register/delete", UserRegistrationController, :delete)
  end

  scope "/", ClaperWeb do
    pipe_through([:browser])

    get("/tos", PageController, :tos)
    get("/privacy", PageController, :privacy)

    delete("/users/log_out", UserSessionController, :delete)
  end
end
