## v1.5.0

- Add a nickname feature and toggle button to avoid anonymous messages
- Add url information on the instruction page with QR Code
- Add German locale (thanks to @Dynnammo)
- Update Moment Timezone, Moment to patch security vulnerabilities
- Update TailwindCSS 2 to 3
- Fix layout on the moderator page for messages list
- Fix event link color being white

## v1.4.1

- Add GS_JPG_RESOLUTION environment variable to configure the resolution of the JPG generated from PDF (#40 - thanks @mokaddem)
- Fix MAX_FILE_SIZE_MB not being updated

## v1.4.0

- Migrate to Phoenix 1.7
- Migrate to Liveview 0.18
- Add multiple choice poll
- Add feature to import all interactions from another presentation
- Add MAX_FILE_SIZE_MB environment variable to limit file upload size
- Add feature to deactivate messages during a presentation


## v1.3.0

- Add Form feature to collect data from your public
- Improve docs for Docker Compose
- Improve Docker Compose file reference


## v1.2.1

- Fix presenter url (400 error in production)


## v1.2.0

- Added password change form in settings
- Added more documentation on deployment in production


## v1.1.1

_Security updates_

- Added `ENABLE_MAILBOX_ROUTE`, `MAILBOX_USER` and `MAILBOX_PASSWORD` environment variables to enable/disable route to local mailbox (`/dev/mailbox`) and basic auth (optional)
- Restricted `/users/register` route if `ENABLE_ACCOUNT_CREATION` is false


## v1.1.0

- Added password authentication
- Removed passwordless authentication
- Disabled email verification
- Added new `ENABLE_ACCOUNT_CREATION` environment variable to enable or disable user registration
- Improved french localization


## v1.0.0

This is the first version of the open-source project. Feel free to contribute!
