## v1.0.0

This is the first version of the open-source project. Feel free to contribute!

## v1.1.0

- Added password authentication
- Removed passwordless authentication
- Disabled email verification
- Added new `ENABLE_ACCOUNT_CREATION` environment variable to enable or disable user registration
- Improved french localization

## v1.1.1

_Security updates_

- Added `ENABLE_MAILBOX_ROUTE`, `MAILBOX_USER` and `MAILBOX_PASSWORD` environment variables to enable/disable route to local mailbox (`/dev/mailbox`) and basic auth (optional)
- Restricted `/users/register` route if `ENABLE_ACCOUNT_CREATION` is false

## v1.2.0

- Added password change form in settings
- Added more documentation on deployment in production

## v1.2.1
- Fix presenter url (400 error in production)