defmodule ClaperWeb.Notifiers.User.NotifierComponents do
  @moduledoc """
  Contains function components for rendering emails for user notifications.
  """
  # Imports layout function from this module
  # Important to have so the emails are rendered properly
  import ClaperWeb.Notifiers.EmailLayout
  import Phoenix.HTML, only: [raw: 1]
  use Phoenix.Component
  use Gettext, backend: ClaperWeb.Gettext

  defp confirm_template(assigns) do
    ~H"""
    <.layout>
      <tr>
        <td>
          <table
            width="95%"
            border="0"
            align="center"
            cellpadding="0"
            cellspacing="0"
            style="max-width:670px;background:#fff; border-radius:3px; text-align:center;-webkit-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);-moz-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);box-shadow:0 6px 18px 0 rgba(0,0,0,.06);"
          >
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="padding:0 35px;">
                <h1 style="color:#1e1e2d; font-weight:500; margin:0;font-size:32px;font-family:'Rubik',sans-serif;">
                  {gettext("Confirm account")}
                </h1>
                <span style="display:inline-block; vertical-align:middle; margin:29px 0 26px; border-bottom:1px solid #cecece; width:100px;">
                </span>
                <p style="color:#455056; font-size:15px;line-height:24px; margin:0;">
                  {gettext("You can confirm your account by visiting the URL below")}
                </p>
                <a
                  href={@url}
                  target="_blank"
                  style="background:#8611ed;text-decoration:none !important; font-weight:500; margin-top:35px; color:#fff;text-transform:uppercase; font-size:14px;padding:10px 24px;display:inline-block;border-radius:50px;"
                >
                  {gettext("CONFIRM ACCOUNT")}
                </a>
                <p style="color:#455056; font-size:15px;line-height:24px; margin-top:26px;">
                  {gettext("If you didn't create an account with us, please ignore this.")}
                </p>
              </td>
            </tr>
            <tr>
              <td style="height:20px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="font-size: 0.8em; color: #6C6C6C">
                <p class="sub">
                  {gettext(
                    "If you’re having trouble with the button above, copy and paste the URL below into your web browser"
                  )}.
                </p>
                <p class="sub">{@url}</p>
              </td>
            </tr>
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td style="height:20px;">&nbsp;</td>
      </tr>
    </.layout>
    """
  end

  defp change_template(assigns) do
    ~H"""
    <.layout>
      <tr>
        <td>
          <table
            width="95%"
            border="0"
            align="center"
            cellpadding="0"
            cellspacing="0"
            style="max-width:670px;background:#fff; border-radius:3px; text-align:center;-webkit-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);-moz-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);box-shadow:0 6px 18px 0 rgba(0,0,0,.06);"
          >
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="padding:0 35px;">
                <h1 style="color:#1e1e2d; font-weight:500; margin:0;font-size:32px;font-family:'Rubik',sans-serif;">
                  {gettext("Confirm email change")}
                </h1>
                <span style="display:inline-block; vertical-align:middle; margin:29px 0 26px; border-bottom:1px solid #cecece; width:100px;">
                </span>
                <p style="color:#455056; font-size:15px;line-height:24px; margin:0;">
                  {gettext("You can confirm your email change by visiting the URL below")}
                </p>
                <a
                  href={@url}
                  target="_blank"
                  style="background:#8611ed;text-decoration:none !important; font-weight:500; margin-top:35px; color:#fff;text-transform:uppercase; font-size:14px;padding:10px 24px;display:inline-block;border-radius:50px;"
                >
                  {gettext("CONFIRM EMAIL")}
                </a>
                <p style="color:#455056; font-size:15px;line-height:24px; margin-top:26px;">
                  {gettext("If you didn't request an email change, please ignore this.")}
                </p>
              </td>
            </tr>
            <tr>
              <td style="height:20px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="font-size: 0.8em; color: #6C6C6C">
                <p class="sub">
                  {gettext(
                    "If you’re having trouble with the button above, copy and paste the URL below into your web browser"
                  )}.
                </p>
                <p class="sub">{@url}</p>
              </td>
            </tr>
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td style="height:20px;">&nbsp;</td>
      </tr>
    </.layout>
    """
  end

  defp reset_template(assigns) do
    ~H"""
    <.layout>
      <tr>
        <td>
          <table
            width="95%"
            border="0"
            align="center"
            cellpadding="0"
            cellspacing="0"
            style="max-width:670px;background:#fff; border-radius:3px; text-align:center;-webkit-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);-moz-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);box-shadow:0 6px 18px 0 rgba(0,0,0,.06);"
          >
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="padding:0 35px;">
                <h1 style="color:#1e1e2d; font-weight:500; margin:0;font-size:32px;font-family:'Rubik',sans-serif;">
                  {gettext("Reset password")}
                </h1>
                <span style="display:inline-block; vertical-align:middle; margin:29px 0 26px; border-bottom:1px solid #cecece; width:100px;">
                </span>
                <p style="color:#455056; font-size:15px;line-height:24px; margin:0;">
                  {gettext("You can reset your password by visiting the URL below")}
                </p>
                <a
                  href={@url}
                  target="_blank"
                  style="background:#8611ed;text-decoration:none !important; font-weight:500; margin-top:35px; color:#fff;text-transform:uppercase; font-size:14px;padding:10px 24px;display:inline-block;border-radius:50px;"
                >
                  {gettext("RESET PASSWORD")}
                </a>
                <p style="color:#455056; font-size:15px;line-height:24px; margin-top:26px;">
                  {gettext("If you didn't create an account with us, please ignore this.")}
                </p>
              </td>
            </tr>
            <tr>
              <td style="height:20px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="font-size: 0.8em; color: #6C6C6C">
                <p class="sub">
                  {gettext(
                    "If you’re having trouble with the button above, copy and paste the URL below into your web browser"
                  )}.
                </p>
                <p class="sub">{@url}</p>
              </td>
            </tr>
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td style="height:20px;">&nbsp;</td>
      </tr>
    </.layout>
    """
  end

  defp magic_template(assigns) do
    ~H"""
    <.layout>
      <tr>
        <td>
          <table
            width="95%"
            border="0"
            align="center"
            cellpadding="0"
            cellspacing="0"
            style="max-width:670px;background:#fff; border-radius:3px; text-align:center;-webkit-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);-moz-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);box-shadow:0 6px 18px 0 rgba(0,0,0,.06);"
          >
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="padding:0 35px;">
                <h1 style="color:#1e1e2d; font-weight:500; margin:0;font-size:32px;font-family:'Rubik',sans-serif;">
                  {gettext("Connect to Claper")}
                </h1>
                <span style="display:inline-block; vertical-align:middle; margin:29px 0 26px; border-bottom:1px solid #cecece; width:100px;">
                </span>
                <p style="color:#455056; font-size:15px;line-height:24px; margin:0;">
                  {gettext("You can log into your account by clicking here.")}
                </p>
                <a
                  href={@url}
                  target="_blank"
                  style="background:#8611ed;text-decoration:none !important; font-weight:500; margin-top:35px; color:#fff;text-transform:uppercase; font-size:14px;padding:10px 24px;display:inline-block;border-radius:50px;"
                >
                  {gettext("ACCESS TO MY ACCOUNT")}
                </a>
                <p style="color:#455056; font-size:15px;line-height:24px; margin-top:26px;">
                  {gettext("If you didn't create an account with us, please ignore this.")}
                </p>
              </td>
            </tr>
            <tr>
              <td style="height:20px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="font-size: 0.8em; color: #6C6C6C">
                <p class="sub">
                  {gettext(
                    "If you’re having trouble with the button above, copy and paste the URL below into your web browser"
                  )}.
                </p>
                <p class="sub">{@url}</p>
              </td>
            </tr>
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td style="height:20px;">&nbsp;</td>
      </tr>
    </.layout>
    """
  end

  defp welcome_template(assigns) do
    ~H"""
    <.layout>
      <tr>
        <td>
          <table
            width="95%"
            border="0"
            align="center"
            cellpadding="0"
            cellspacing="0"
            style="max-width:670px;background:#fff; border-radius:3px; text-align:center;-webkit-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);-moz-box-shadow:0 6px 18px 0 rgba(0,0,0,.06);box-shadow:0 6px 18px 0 rgba(0,0,0,.06);"
          >
            <tr>
              <td style="height:40px;">&nbsp;</td>
            </tr>
            <tr>
              <td style="padding:0 35px;">
                <h1 style="color:#1e1e2d; font-weight:500; margin:0;font-size:32px;font-family:'Rubik',sans-serif;">
                  {gettext("Welcome !")}
                </h1>
                <span style="display:inline-block; vertical-align:middle; margin:29px 0 26px; border-bottom:1px solid #cecece; width:100px;">
                </span>
                <p style="color:#455056; font-size:15px;line-height:24px; margin:0;">
                  {gettext(
                    "Congrats! You've taken the first step to improving your presentations. Here are the next steps to create step up your presentations with Claper:"
                  )}
                </p>
                <ol style="color:#455056; font-size:15px;line-height:24px; margin:10px 0px; text-align: left;">
                  <li>
                    {raw(
                      gettext(
                        "<span style='font-weight: 700'>Export your current presentation</span> to PDF from your favorite slide presentation software (PowerPoint, etc)"
                      )
                    )}
                  </li>
                  <li>
                    {raw(
                      gettext(
                        "Click on the <span style='font-weight: 700'>create button</span> on your dashboard"
                      )
                    )}
                  </li>
                  <li>
                    {raw(
                      gettext(
                        "Choose <span style='font-weight: 700'>a name</span> for your event, <span style='font-weight: 700'>a code</span> for your attendees to join and <span style='font-weight: 700'>dates when your attendees could start interacting</span>"
                      )
                    )}
                  </li>
                  <li>
                    {raw(
                      gettext(
                        "<span style='font-weight: 700'>Wait few minutes</span> for your file to be processed"
                      )
                    )}
                  </li>
                  <li>
                    {raw(
                      gettext(
                        "Click on <span style='font-weight: 700'>Present/Customize</span> to add interaction on your slides"
                      )
                    )}
                  </li>
                  <li>
                    {raw(
                      gettext(
                        "Click <span style='font-weight: 700'>Start</span> to open your presentation and move the window on the big screen"
                      )
                    )}
                  </li>
                  <li>{gettext("Enjoy ! ✨")}</li>
                </ol>
              </td>
            </tr>
            <tr>
              <td style="height:20px;">&nbsp;</td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td style="height:20px;">&nbsp;</td>
      </tr>
    </.layout>
    """
  end

  def welcome(assigns) do
    assigns
    |> welcome_template()
    |> heex_to_html()
  end

  def magic(assigns) do
    assigns
    |> magic_template()
    |> heex_to_html()
  end

  def reset(assigns) do
    assigns
    |> reset_template()
    |> heex_to_html()
  end

  def change(assigns) do
    assigns
    |> change_template()
    |> heex_to_html()
  end

  def confirm(assigns) do
    assigns
    |> confirm_template()
    |> heex_to_html()
  end
end
