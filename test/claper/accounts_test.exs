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

  describe "OIDC user names" do
    test "populates names from standard claims" do
      attrs = oidc_user_attrs()

      assert {:ok, oidc_user} = Accounts.get_or_create_user_with_oidc(attrs)
      assert oidc_user.user.first_name == "OIDC"
      assert oidc_user.user.last_name == "User"
    end

    test "fills missing names on a later login" do
      attrs = oidc_user_attrs(%{first_name: nil, last_name: nil})
      assert {:ok, oidc_user} = Accounts.get_or_create_user_with_oidc(attrs)
      assert is_nil(oidc_user.user.first_name)

      assert {:ok, oidc_user} =
               Accounts.get_or_create_user_with_oidc(%{
                 attrs
                 | first_name: "Later",
                   last_name: "Claim"
               })

      assert oidc_user.user.first_name == "Later"
      assert oidc_user.user.last_name == "Claim"
    end

    test "does not overwrite locally stored names" do
      user = user_fixture(first_name: "Local", last_name: "Name")
      attrs = oidc_user_attrs(%{email: user.email})

      assert {:ok, oidc_user} = Accounts.get_or_create_user_with_oidc(attrs)
      assert oidc_user.user.first_name == "Local"
      assert oidc_user.user.last_name == "Name"
    end

    test "creates a new account when the previous account with that email was deleted" do
      deleted_user = user_fixture()
      assert {:ok, deleted_user} = Accounts.delete_user(deleted_user)

      assert {:ok, oidc_user} =
               Accounts.get_or_create_user_with_oidc(
                 oidc_user_attrs(%{email: deleted_user.email})
               )

      refute oidc_user.user.id == deleted_user.id
      refute Accounts.deleted?(oidc_user.user)
      assert Accounts.get_user_by_email(deleted_user.email).id == oidc_user.user.id
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
