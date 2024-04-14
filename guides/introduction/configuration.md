# Configuration

## Environment file

All configuration used by the app is stored in the `.env` file. You can find an example file in `.env.sample`, but you should copy it to `.env` and fill it with your own values (described below).

### Storage

| Variable                 | Values    | Default                               | Required      | Description                                                                                                                                                                                          |
| ------------------------ | --------- | ------------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PRESENTATION_STORAGE     | local, s3 | local                                 | -             | Define where the presentation files will be stored                                                                                                                                                   |
| PRESENTATION_STORAGE_DIR | -         | priv/static (/app/uploads for Docker) | -             | If `local` storage is used, this is the directory where the presentation files will be stored. Compile-time config, so you need to recompile the app if you change it (or rebuild the Docker image). |
| AWS_ACCESS_KEY_ID        | -         | -                                     | _only for s3_ | Your AWS Access Key ID                                                                                                                                                                               |
| AWS_SECRET_ACCESS_KEY    | -         | -                                     | _only for s3_ | Your AWS Secret Access Key                                                                                                                                                                           |
| AWS_PRES_BUCKET          | -         | -                                     | _only for s3_ | The name of the bucket where the presentation files will be stored                                                                                                                                   |
| AWS_REGION               | -         | -                                     | _only for s3_ | The region where the bucket is located                                                                                                                                                               |

### Mail

| Variable             | Values                      | Default           | Required            | Description                                            |
| -------------------- | --------------------------- | ----------------- | ------------------- | ------------------------------------------------------ |
| MAIL_TRANSPORT       | local, smtp, postmark       | local             | -                   | Define how the emails will be sent                     |
| MAIL_FROM            | -                           | Claper            | -                   | Email address used to send emails                      |
| MAIL_FROM_NAME       | -                           | noreply@claper.co | -                   | Name used to send emails                               |
| SMTP_RELAY           | -                           | -                 | _only for smtp_     | SMTP relay server                                      |
| SMTP_USERNAME        | -                           | -                 | _only for smtp_     | SMTP username                                          |
| SMTP_PASSWORD        | -                           | -                 | _only for smtp_     | SMTP password                                          |
| SMTP_PORT            | -                           | 25                | -                   | SMTP port                                              |
| SMTP_TLS             | always, never, if_available | always            | -                   | SMTP TLS                                               |
| SMTP_AUTH            | always, never, if_available | always            | -                   | SMTP Auth                                              |
| SMTP_SSL             | true, false                 | true              | -                   | SMTP SSL                                               |
| ENABLE_MAILBOX_ROUTE | true, false                 | false             | -                   | Enable/disable route to local mailbox (`/dev/mailbox`) |
| MAILBOX_USER         | -                           | -                 | -                   | Basic auth user for mailbox route                      |
| MAILBOX_PASSWORD     | -                           | -                 | -                   | Basic auth password for mailbox route                  |
| POSTMARK_API_KEY     | -                           | -                 | _only for postmark_ | Postmark API key                                       |

### Application

| Variable                | Values      | Default | Required | Description                                                                                             |
| ----------------------- | ----------- | ------- | -------- | ------------------------------------------------------------------------------------------------------- |
| ENABLE_ACCOUNT_CREATION | true, false | true    | -        | Enable/disable user registration                                                                        |
| MAX_FILE_SIZE_MB        | -           | 15      | -        | Max file size to upload in MB                                                                           |
| GS_JPG_RESOLUTION       | -           | 300x300 | -        | Resolution (DPI) of the JPG generated from PDF, higher resolution means bigger files but better quality |
| SAME_SITE_COOKIE        | Lax, None   | Lax     | -        | SameSite attribute for cookies                                                                          |
| SECURE_COOKIE           | true, false | false   | -        | Secure attribute for cookies                                                                            |

## Production / Docker

You can use all local variables plus the following:

| Variable        | Values | Default | Required | Description                                    |
| --------------- | ------ | ------- | -------- | ---------------------------------------------- |
| DATABASE_URL    | -      | -       | ✓        | Postgres connection string                     |
| SECRET_KEY_BASE | -      | -       | ✓        | Generate it with `mix phx.gen.secret`          |
| BASE_URL        | -      | -       | ✓        | Base URL of the app (e.g. `https://claper.co`) |
| PORT            | -      | 4000    | -        | Port to listen to                              |
