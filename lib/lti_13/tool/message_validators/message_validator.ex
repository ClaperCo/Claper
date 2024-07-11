defprotocol Lti_1p3.Tool.MessageValidator do

  @spec can_validate(any) :: boolean
  def can_validate(jwt_body)

  @spec validate(any) :: {:ok} | {:error, String.t()}
  def validate(jwt_body)
end
