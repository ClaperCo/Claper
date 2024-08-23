defmodule Lti13.Tool.Services.NRPS.Membership do
  # See https://www.imsglobal.org/spec/lti-nrps/v2p0#context-membership

  @derive Jason.Encoder
  @enforce_keys [
    :status,
    :name,
    :picture,
    :given_name,
    :middle_name,
    :family_name,
    :email,
    :user_id,
    :roles
  ]
  defstruct [
    :status,
    :name,
    :picture,
    :given_name,
    :middle_name,
    :family_name,
    :email,
    :user_id,
    :roles
  ]

  @type t() :: %__MODULE__{
          status: String.t(),
          name: String.t(),
          picture: String.t(),
          given_name: String.t(),
          middle_name: String.t(),
          family_name: String.t(),
          email: String.t(),
          user_id: String.t(),
          roles: [String.t()]
        }
end
