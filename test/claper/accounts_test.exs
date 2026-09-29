defmodule Claper.AccountsTest do
  use Claper.DataCase

  alias Claper.Accounts

  import Claper.AccountsFixtures
  alias Claper.Accounts.{User, UserToken}

  require Logger

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "magic_token_valid?/1" do
    test "does not return true if the email is not valid" do
      refute Accounts.magic_token_valid?("unknown@example.com")
    end

    test "does return true if token valid" do
      user = user_fixture()

      Accounts.deliver_magic_link(user.email, fn _url -> "URL" end)

      assert Accounts.magic_token_valid?(user.email) == true
    end
  end

  describe "deliver_magic_link/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends magic link through notification", %{user: user} do
      {:ok, token} = Accounts.deliver_magic_link(user.email, &"/users/magic/#{&1}")

      {:ok, token} = Base.url_decode64(token, padding: false)

      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))

      # No user_id, we only check the user when the link is clicked
      refute user_token.user_id

      assert user_token.sent_to == user.email
      assert user_token.context == "magic"
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})

      assert Enum.sort(changeset.required) ==
               Enum.sort([:email, :first_name, :last_name, :password])
    end

    test "allows fields to be set" do
      email = unique_user_email()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(email: email)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :first_name) == "John"
      assert get_change(changeset, :last_name) == "Doe"
    end

    test "validates password confirmation" do
      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(password_confirmation: "does not match")
        )

      refute changeset.valid?
      assert "does not match confirmation" in errors_on(changeset).password_confirmation
    end

    test "limits passwords to bcrypt's 72-byte input" do
      at_limit = String.duplicate("é", 36)
      over_limit = String.duplicate("é", 37)

      assert Accounts.change_user_registration(
               %User{},
               valid_user_attributes(password: at_limit, password_confirmation: at_limit)
             ).valid?

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(password: over_limit, password_confirmation: over_limit)
        )

      assert "is too long" in errors_on(changeset).password
    end

    test "admin changes apply the same 72-byte password limit" do
      changeset = Accounts.change_user(%User{}, %{password: String.duplicate("é", 37)})

      assert "is too long" in errors_on(changeset).password
    end

    test "existing users with passwords over 72 bytes can still log in" do
      user = user_fixture()
      password = String.duplicate("é", 37)

      user
      |> Ecto.Changeset.change(hashed_password: Bcrypt.hash_pwd_salt(password))
      |> Claper.Repo.update!()

      assert %User{id: id} = Accounts.get_user_by_email_and_password(user.email, password)
      assert id == user.id
    end
  end

  describe "user profile" do
    test "updates and normalizes the user's names" do
      user = user_fixture()

      assert {:ok, updated_user} =
               Accounts.update_user_profile(user, %{
                 first_name: "  Jane ",
                 last_name: " Smith  "
               })

      assert updated_user.first_name == "Jane"
      assert updated_user.last_name == "Smith"
    end

    test "requires both names" do
      user = user_fixture()

      assert {:error, changeset} =
               Accounts.update_user_profile(user, %{first_name: "", last_name: "Smith"})

      assert "can't be blank" in errors_on(changeset).first_name
    end

    test "fills missing external names without overwriting local values" do
      {:ok, user} =
        Accounts.create_user(%{
          email: unique_user_email(),
          password: valid_user_password(),
          first_name: "Local"
        })

      assert {:ok, updated_user} =
               Accounts.fill_missing_user_names(user, %{
                 first_name: "External",
                 last_name: "Name"
               })

      assert updated_user.first_name == "Local"
      assert updated_user.last_name == "Name"
    end

    test "uses the email as the display name when names are missing" do
      assert User.display_name(%User{email: "user@example.com"}) == "user@example.com"

      assert User.display_name(%User{
               email: "user@example.com",
               first_name: "Jane",
               last_name: "Smith"
             }) == "Jane Smith"
    end
  end

  describe "OIDC account resolution" do
    # config/runtime.exs replaces the test adapter with the one MAIL_TRANSPORT selects.
    setup do
      mailer_config = Application.get_env(:claper, Claper.Mailer)
      Application.put_env(:claper, Claper.Mailer, adapter: Swoosh.Adapters.Test)
      on_exit(fn -> Application.put_env(:claper, Claper.Mailer, mailer_config) end)
    end

    test "an unverified email claim never links an existing account by itself" do
      victim = user_fixture()

      for verification <- [false, nil, "true", 1, :missing] do
        attrs =
          oidc_user_attrs(%{
            email: victim.email,
            email_verified: verification,
            first_name: "Attacker"
          })

        attrs =
          if verification == :missing, do: Map.delete(attrs, :email_verified), else: attrs

        assert {:confirmation_sent, _browser_secret} = authenticate(attrs)
        assert_received {:oidc_confirmation_token, _token}
        assert Accounts.get_all_oidc_users_by_email(victim.email) == []
        assert Accounts.get_user!(victim.id).first_name == victim.first_name
      end
    end

    test "the emailed link is useless outside the browser that started the sign-in" do
      victim = user_fixture()
      victim_email = victim.email
      attrs = oidc_user_attrs(%{email: victim_email, email_verified: false})

      assert {:confirmation_sent, attacker_secret} = authenticate(attrs)
      assert_received {:oidc_confirmation_token, token}
      assert_received {:email, %Swoosh.Email{to: [{_, ^victim_email}]}}

      # The victim opens the link in their own browser; the attacker never sees the token.
      assert Accounts.confirm_oidc_identity(token, random_token()) == :error
      assert Accounts.confirm_oidc_identity(token, nil) == :error
      assert Accounts.confirm_oidc_identity(random_token(), attacker_secret) == :error
      assert Accounts.confirm_oidc_identity("not base64!", attacker_secret) == :error
      assert Accounts.get_all_oidc_users_by_email(victim_email) == []
    end

    test "the mailbox owner confirms a new identity once, then signs in directly" do
      attrs = oidc_user_attrs(%{email_verified: false})

      assert {:confirmation_sent, secret} = authenticate(attrs)
      assert_received {:oidc_confirmation_token, token}
      refute Accounts.get_user_by_email(attrs.email)

      assert {:ok, identity} = Accounts.confirm_oidc_identity(token, secret)
      assert identity.user.email == attrs.email
      assert identity.user.confirmed_at
      assert identity.verified_at
      assert Accounts.confirm_oidc_identity(token, secret) == :error

      assert {:ok, returning} = authenticate(%{attrs | access_token: "later-token"})
      assert returning.id == identity.id
      assert returning.access_token == "later-token"
      refute_received {:oidc_confirmation_token, _}
    end

    test "confirming an existing account's email links that account" do
      user = user_fixture()
      attrs = oidc_user_attrs(%{email: user.email, email_verified: nil})

      assert {:confirmation_sent, secret} = authenticate(attrs)
      assert_received {:oidc_confirmation_token, token}
      assert {:ok, identity} = Accounts.confirm_oidc_identity(token, secret)
      assert identity.user.id == user.id
    end

    test "confirmation links expire after 15 minutes" do
      attrs = oidc_user_attrs(%{email_verified: false})
      assert {:confirmation_sent, secret} = authenticate(attrs)
      assert_received {:oidc_confirmation_token, token}

      sixteen_minutes_ago =
        NaiveDateTime.utc_now() |> NaiveDateTime.add(-16 * 60) |> NaiveDateTime.truncate(:second)

      Repo.update_all(Accounts.Oidc.PendingIdentity, set: [inserted_at: sixteen_minutes_ago])

      assert Accounts.confirm_oidc_identity(token, secret) == :error
      refute Accounts.get_user_by_email(attrs.email)
    end

    test "a newer sign-in invalidates the previous confirmation link" do
      attrs = oidc_user_attrs(%{email_verified: false})
      assert {:confirmation_sent, old_secret} = authenticate(attrs)
      assert_received {:oidc_confirmation_token, old_token}
      assert {:confirmation_sent, secret} = authenticate(attrs)
      assert_received {:oidc_confirmation_token, token}

      assert Accounts.confirm_oidc_identity(old_token, old_secret) == :error
      assert {:ok, _identity} = Accounts.confirm_oidc_identity(token, secret)
    end

    test "bindings created before confirmation existed are confirmed through the bound account" do
      victim = user_fixture()
      victim_email = victim.email
      attrs = oidc_user_attrs(%{email: unique_user_email(), email_verified: false})
      assert {:ok, _legacy} = Accounts.create_oidc_user(Map.put(attrs, :user_id, victim.id))

      assert {:confirmation_sent, secret} = authenticate(attrs)
      assert_received {:oidc_confirmation_token, token}
      assert_received {:email, %Swoosh.Email{to: [{_, ^victim_email}]}}

      assert {:ok, identity} = Accounts.confirm_oidc_identity(token, secret)
      assert identity.user.id == victim.id
      assert identity.verified_at
      assert {:ok, _returning} = authenticate(attrs)
      refute_received {:oidc_confirmation_token, _}
    end

    test "a legacy binding is verified when the provider asserts the account's email" do
      user = user_fixture()
      attrs = oidc_user_attrs(%{email: user.email})
      assert {:ok, _legacy} = Accounts.create_oidc_user(Map.put(attrs, :user_id, user.id))

      assert {:ok, identity} = authenticate(attrs)
      assert identity.user.id == user.id
      assert identity.verified_at
    end

    test "verified bindings sign in without verification or email claims" do
      attrs = oidc_user_attrs()
      assert {:ok, original} = authenticate(attrs)

      for claims <- [%{attrs | email_verified: false}, Map.drop(attrs, [:email, :email_verified])] do
        assert {:ok, returning} = authenticate(claims)
        assert returning.id == original.id
        assert returning.email == attrs.email
      end

      refute_received {:oidc_confirmation_token, _}
    end

    test "disabled accounts cannot sign in through their binding" do
      attrs = oidc_user_attrs()
      assert {:ok, identity} = authenticate(attrs)
      assert {:ok, _} = Accounts.delete_user(identity.user)

      assert {:error, :invalid_user} = authenticate(attrs)
    end

    test "the same subject at different issuers cannot redirect an account binding" do
      first_attrs = oidc_user_attrs()
      assert {:ok, first} = authenticate(first_attrs)

      second_attrs = %{
        first_attrs
        | issuer: "https://another-issuer.example.com",
          email: unique_user_email()
      }

      assert {:ok, second} = authenticate(second_attrs)
      refute second.id == first.id
      refute second.user.id == first.user.id
      assert second.issuer == second_attrs.issuer

      assert {:ok, returning} = authenticate(first_attrs)
      assert returning.id == first.id
      assert returning.user.id == first.user.id
      assert returning.issuer == first_attrs.issuer
    end

    test "a returning identity keeps its local account when its verified email changes" do
      attrs = oidc_user_attrs()
      assert {:ok, original} = authenticate(attrs)
      other_user = user_fixture()

      assert {:ok, returning} = authenticate(%{attrs | email: other_user.email})

      assert returning.id == original.id
      assert returning.user.id == original.user.id
      assert returning.user.email == attrs.email
      refute returning.user.id == other_user.id
    end

    test "one issuer and subject cannot be linked to two local accounts" do
      attrs = oidc_user_attrs()
      assert {:ok, original} = authenticate(attrs)
      other_user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Accounts.create_oidc_user(Map.put(attrs, :user_id, other_user.id))

      assert {:ok, returning} = authenticate(attrs)
      assert returning.id == original.id
      assert returning.user.id == original.user.id
    end

    test "incomplete identity claims neither link an account nor send email" do
      victim = user_fixture()

      for verification <- [true, false],
          field <- [:issuer, :sub, :email],
          value <- [nil, ""] do
        attrs = oidc_user_attrs(%{email: victim.email, email_verified: verification})

        assert {:error, _reason} = authenticate(Map.put(attrs, field, value))
        assert Accounts.get_all_oidc_users_by_email(victim.email) == []
      end

      refute_received {:oidc_confirmation_token, _}
    end

    test "populates names from standard claims" do
      attrs = oidc_user_attrs()

      assert {:ok, oidc_user} = authenticate(attrs)
      assert oidc_user.user.first_name == "OIDC"
      assert oidc_user.user.last_name == "User"
    end

    test "fills missing names on a later login" do
      attrs = oidc_user_attrs(%{first_name: nil, last_name: nil})
      assert {:ok, oidc_user} = authenticate(attrs)
      assert is_nil(oidc_user.user.first_name)

      assert {:ok, oidc_user} = authenticate(%{attrs | first_name: "Later", last_name: "Claim"})

      assert oidc_user.user.first_name == "Later"
      assert oidc_user.user.last_name == "Claim"
    end

    test "does not overwrite locally stored names" do
      user = user_fixture(first_name: "Local", last_name: "Name")
      attrs = oidc_user_attrs(%{email: user.email})

      assert {:ok, oidc_user} = authenticate(attrs)
      assert oidc_user.user.id == user.id
      assert oidc_user.user.first_name == "Local"
      assert oidc_user.user.last_name == "Name"
    end

    test "creates a new account when the previous account with that email was deleted" do
      deleted_user = user_fixture()
      assert {:ok, deleted_user} = Accounts.delete_user(deleted_user)

      assert {:ok, oidc_user} = authenticate(oidc_user_attrs(%{email: deleted_user.email}))

      refute oidc_user.user.id == deleted_user.id
      refute Accounts.deleted?(oidc_user.user)
      assert Accounts.get_user_by_email(deleted_user.email).id == oidc_user.user.id
    end
  end

  describe "restore_user/1" do
    test "lets a disabled user log in again" do
      user = user_fixture()
      {:ok, user} = Accounts.delete_user(user)

      assert {:ok, user} = Accounts.restore_user(user)
      refute Accounts.deleted?(user)
      assert Accounts.get_user_by_email(user.email).id == user.id
    end

    test "fails when another active account took the email" do
      user = user_fixture()
      {:ok, user} = Accounts.delete_user(user)
      _new_account = user_fixture(%{email: user.email})

      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.restore_user(user)
      assert %{email: [_]} = errors_on(changeset)
    end
  end

  describe "hard_delete_user/1" do
    import Claper.{EventsFixtures, PollsFixtures, PostsFixtures, PresentationsFixtures}
    import Claper.QuizzesFixtures

    alias Claper.{Polls, Posts, Quizzes, Repo}

    test "deletes the user and their events but keeps their interactions in other events" do
      user = user_fixture()
      owned_file = presentation_file_fixture(%{event: event_fixture(%{user: user})})
      owned_poll = poll_fixture(%{presentation_file_id: owned_file.id})

      other_file = presentation_file_fixture()
      other_event = Claper.Events.get_event!(other_file.event_id)
      own_post = post_fixture(%{user: user, event: other_event})

      poll = poll_fixture(%{presentation_file_id: other_file.id})
      [opt | _] = poll.poll_opts
      {:ok, _} = Polls.vote(user.id, other_event.uuid, [opt], poll.id)

      quiz = quiz_fixture(%{presentation_file: other_file, enabled: true})
      [quiz_opt | _] = hd(quiz.quiz_questions).quiz_question_opts
      {:ok, _} = Quizzes.submit_quiz(user, other_event.uuid, [quiz_opt], quiz.id)

      post = post_fixture(%{event: other_event})
      {:ok, reaction} = Posts.create_reaction(%{post: post, icon: "👍", user_id: user.id})

      assert {:ok, _} = Accounts.hard_delete_user(user)

      refute Repo.get(User, user.id)
      refute Repo.get(Claper.Events.Event, owned_file.event_id)
      refute Repo.get(Polls.Poll, owned_poll.id)

      kept_post = Repo.get!(Posts.Post, own_post.id)
      assert is_nil(kept_post.user_id)
      assert "deleted-user-" <> _ = identifier = kept_post.attendee_identifier

      assert [%{user_id: nil, attendee_identifier: ^identifier}] =
               Polls.get_poll_vote(identifier, poll.id)

      assert %{user_id: nil, attendee_identifier: ^identifier} =
               Repo.get!(Posts.Reaction, reaction.id)

      assert Repo.get!(Polls.PollOpt, opt.id).vote_count == 1
      assert Repo.get!(Quizzes.QuizQuestionOpt, quiz_opt.id).response_count == 1
    end

    test "keeps the user's slider answers in other events under the deleted identity" do
      user = user_fixture()
      other_file = presentation_file_fixture()
      other_event = Claper.Events.get_event!(other_file.event_id)
      scale = Claper.ScalesFixtures.scale_fixture(%{presentation_file: other_file})
      {:ok, response} = Claper.Scales.submit_response(other_event.uuid, scale, user.id, "4")

      assert {:ok, _} = Accounts.hard_delete_user(user)

      kept = Repo.get!(Claper.Scales.ScaleResponse, response.id)
      assert is_nil(kept.user_id)
      assert "deleted-user-" <> _ = kept.attendee_identifier
      assert kept.value == 4
    end

    test "deletes the user's audit logs but keeps other users' logs" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, log} = Claper.Audit.log_action(user, "user.login")
      {:ok, other_log} = Claper.Audit.log_action(other_user, "user.login")

      assert {:ok, _} = Accounts.hard_delete_user(user)

      refute Repo.get(Claper.Audit.Log, log.id)
      assert Repo.get(Claper.Audit.Log, other_log.id)
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  defp oidc_user_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        sub: Ecto.UUID.generate(),
        issuer: "https://issuer.example.com",
        name: "OIDC User",
        first_name: "OIDC",
        last_name: "User",
        email: unique_user_email(),
        email_verified: true,
        provider: "Test Provider",
        expires_at: NaiveDateTime.utc_now(),
        id_token: "id-token",
        access_token: "access-token",
        refresh_token: "refresh-token",
        groups: [],
        roles: nil,
        organization: nil,
        photo_url: nil
      },
      overrides
    )
  end

  defp authenticate(attrs) do
    Accounts.authenticate_oidc_identity(attrs, fn token ->
      send(self(), {:oidc_confirmation_token, token})
      "https://claper.test/users/oidc/confirm/#{token}"
    end)
  end

  defp random_token, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} = Accounts.apply_user_email(user, %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()

      {:error, changeset} = Accounts.apply_user_email(user, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      {:ok, token} =
        Accounts.deliver_update_email_instructions(
          user,
          "current@example.com",
          &"/users/settings/confirm_email/#{&1}"
        )

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      {:ok, token} =
        Accounts.deliver_update_email_instructions(
          %{user | email: email},
          user.email,
          &"/users/settings/confirm_email/#{&1}"
        )

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      context = "change:#{user.email}"

      {1, nil} =
        from(ut in UserToken,
          where: ut.user_id == ^user.id and ut.context == ^context
        )
        |> Repo.update_all(set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{user: user, token: token} do
      {1, nil} =
        from(ut in UserToken, where: ut.user_id == ^user.id and ut.context == "session")
        |> Repo.update_all(set: [inserted_at: ~N[2020-01-01 00:00:00]])

      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      {:ok, token} =
        Accounts.deliver_user_confirmation_instructions(user, &"/users/confirm/#{&1}")

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture()

      {:ok, token} =
        Accounts.deliver_user_confirmation_instructions(user, &"/users/confirm/#{&1}")

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} =
        from(ut in UserToken, where: ut.user_id == ^user.id and ut.context == "confirm")
        |> Repo.update_all(set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end
end
