# Configuration

## Environment file

All configuration used by the app is stored in the `.env` file. You can find an example file in `.env.sample`, but you should copy it to `.env` and fill it with your own values (described below).

Variable | Values | Default | Required | Description
--- | --- | --- | --- | ---
PRESENTATION_STORAGE | local, s3 | local | - |  Define where the presentation files will be stored
AWS_ACCESS_KEY_ID | - | - | _only for s3_ | Your AWS Access Key ID
AWS_SECRET_ACCESS_KEY | - | - | _only for s3_ | Your AWS Secret Access Key
AWS_S3_BUCKET | - | - | _only for s3_ | The name of the bucket where the presentation files will be stored
AWS_S3_REGION | - | - | _only for s3_ | The region where the bucket is located
MAIL_TRANSPORT | local, smtp | local | - | Define how the emails will be sent
MAIL_FROM | - | Claper | - | Email address used to send emails
MAIL_FROM_NAME | - | noreply@claper.co | - | Name used to send emails
SMTP_RELAY | - | - |  ✓ | SMTP relay server
SMTP_USERNAME | - | - | ✓ |  SMTP username
SMTP_PASSWORD | - | - |  ✓ | SMTP password
SMTP_PORT | - | 25 | - | SMTP port
SMTP_TLS | always, never, if_available | always | - | SMTP TLS
SMTP_AUTH | always, never, if_available | always | - | SMTP Auth
SMTP_SSL | true, false | true | - | SMTP SSL
ENABLE_ACCOUNT_CREATION | true, false | true | - | Enable/disable user registration

## Production / Docker

You can use all local variables plus the following:

Variable | Values | Default | Required | Description
--- | --- | --- | --- | ---
DATABASE_URL | - | - | ✓ | Postgres connection string
SECRET_KEY_BASE | - | - |  ✓ |  Generate it with `mix phx.gen.secret`
ENDPOINT_HOST | - | localhost |  - | Host used to access the app (used for url generation)
ENDPOINT_PORT | - | 80 |  - | Port used to access the app (used for url generation)
PORT | - | 4000 |  - | Port to listen to