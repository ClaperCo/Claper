defmodule ClaperWeb.Validators.AdminFormValidatorTest do
  use Claper.DataCase

  alias ClaperWeb.Validators.AdminFormValidator
  alias Claper.Accounts.User
  alias Claper.Events.Event
  alias Claper.Accounts.Oidc.Provider

  describe "validate_user/1" do
    test "validates user with valid attributes" do
      valid_attrs = %{
        "email" => "test@example.com",
        "password" => "Password123!",
        "name" => "Test User"
      }

      assert {:ok, validated} = AdminFormValidator.validate_user(valid_attrs)
      assert validated["email"] == "test@example.com"
      assert validated["name"] == "Test User"
      assert Map.has_key?(validated, "password")
    end

    test "returns error with invalid email" do
      invalid_attrs = %{
        "email" => "not-an-email",
        "password" => "Password123!",
        "name" => "Test User"
      }

      assert {:error, errors} = AdminFormValidator.validate_user(invalid_attrs)
      assert "must be a valid email address" in errors
    end

    test "returns error with weak password" do
      invalid_attrs = %{
        "email" => "test@example.com",
        "password" => "short",
        "name" => "Test User"
      }

      assert {:error, errors} = AdminFormValidator.validate_user(invalid_attrs)
      assert "password must be at least 8 characters" in errors
    end

    test "returns error with missing required fields" do
      invalid_attrs = %{
        "name" => "Test User"
      }

      assert {:error, errors} = AdminFormValidator.validate_user(invalid_attrs)
      assert "email is required" in errors
    end
  end

  describe "validate_event/1" do
    test "validates event with valid attributes" do
      valid_attrs = %{
        "name" => "Test Event",
        "description" => "Test event description",
        "start_date" => "2023-01-01T10:00:00",
        "end_date" => "2023-01-01T12:00:00",
        "timezone" => "UTC",
        "status" => "active"
      }

      assert {:ok, validated} = AdminFormValidator.validate_event(valid_attrs)
      assert validated["name"] == "Test Event"
      assert validated["description"] == "Test event description"
    end

    test "returns error with end date before start date" do
      invalid_attrs = %{
        "name" => "Test Event",
        "description" => "Test event description",
        "start_date" => "2023-01-01T12:00:00",
        # End before start
        "end_date" => "2023-01-01T10:00:00",
        "timezone" => "UTC",
        "status" => "active"
      }

      assert {:error, errors} = AdminFormValidator.validate_event(invalid_attrs)
      assert "end date must be after start date" in errors
    end

    test "returns error with missing required fields" do
      invalid_attrs = %{
        "description" => "Test event description"
      }

      assert {:error, errors} = AdminFormValidator.validate_event(invalid_attrs)
      assert "name is required" in errors
    end

    test "returns error with invalid status" do
      invalid_attrs = %{
        "name" => "Test Event",
        "description" => "Test event description",
        "start_date" => "2023-01-01T10:00:00",
        "end_date" => "2023-01-01T12:00:00",
        "timezone" => "UTC",
        "status" => "invalid_status"
      }

      assert {:error, errors} = AdminFormValidator.validate_event(invalid_attrs)
      assert "status must be one of: active, draft, completed, cancelled" in errors
    end
  end

  describe "validate_oidc_provider/1" do
    test "validates provider with valid attributes" do
      valid_attrs = %{
        "name" => "Test Provider",
        "issuer" => "https://example.com",
        "client_id" => "test_client_id",
        "client_secret" => "test_client_secret",
        "redirect_uri" => "https://app.example.com/callback",
        "scope" => "openid email profile",
        "active" => "true"
      }

      assert {:ok, validated} = AdminFormValidator.validate_oidc_provider(valid_attrs)
      assert validated["name"] == "Test Provider"
      assert validated["issuer"] == "https://example.com"
      assert validated["client_id"] == "test_client_id"
    end

    test "returns error with invalid URLs" do
      invalid_attrs = %{
        "name" => "Test Provider",
        "issuer" => "invalid-url",
        "client_id" => "test_client_id",
        "client_secret" => "test_client_secret",
        "redirect_uri" => "invalid-url",
        "scope" => "openid email profile"
      }

      assert {:error, errors} = AdminFormValidator.validate_oidc_provider(invalid_attrs)
      assert "issuer must be a valid URL starting with http:// or https://" in errors
      assert "redirect_uri must be a valid URL starting with http:// or https://" in errors
    end

    test "returns error with missing required fields" do
      invalid_attrs = %{
        "name" => "Test Provider"
      }

      assert {:error, errors} = AdminFormValidator.validate_oidc_provider(invalid_attrs)
      assert "issuer is required" in errors
      assert "client_id is required" in errors
      assert "client_secret is required" in errors
    end
  end

  describe "add_validation_errors/2" do
    test "adds validation errors to user changeset" do
      changeset = User.changeset(%User{}, %{email: "test@example.com", password: "Password123!"})
      validation_errors = ["Custom error 1", "Custom error 2"]

      result = AdminFormValidator.add_validation_errors(changeset, validation_errors)

      assert %Ecto.Changeset{} = result
      assert result.errors != changeset.errors
      assert length(result.errors) > length(changeset.errors)

      # Extract error messages
      error_messages = Enum.map(result.errors, fn {_, {msg, _}} -> msg end)
      assert "Custom error 1" in error_messages
      assert "Custom error 2" in error_messages
    end

    test "adds validation errors to event changeset" do
      changeset =
        Event.changeset(%Event{}, %{name: "Test Event", description: "Test description"})

      validation_errors = ["Custom event error"]

      result = AdminFormValidator.add_validation_errors(changeset, validation_errors)

      assert %Ecto.Changeset{} = result
      assert result.errors != changeset.errors

      # Extract error messages
      error_messages = Enum.map(result.errors, fn {_, {msg, _}} -> msg end)
      assert "Custom event error" in error_messages
    end

    test "adds validation errors to provider changeset" do
      changeset =
        Provider.changeset(%Provider{}, %{name: "Test Provider", issuer: "https://example.com"})

      validation_errors = ["Custom provider error"]

      result = AdminFormValidator.add_validation_errors(changeset, validation_errors)

      assert %Ecto.Changeset{} = result
      assert result.errors != changeset.errors

      # Extract error messages
      error_messages = Enum.map(result.errors, fn {_, {msg, _}} -> msg end)
      assert "Custom provider error" in error_messages
    end
  end
end
