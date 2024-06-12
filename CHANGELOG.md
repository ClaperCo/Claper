## v2.0.1

### Features

- Add Dutch translation #91 (@robinaartsma)
- Add dynamic layout for the presenter view

### Fixes and improvements

- Fix responsive layout on dashboard
- Fix presenter layout with embeds when messages are hidden
- Fix missing stream for form submits
- Fix unknown locales
- Fix embeds when updated
- Add validation to avoid user to self assign as a facilitator
- Toggle for message reactions is replaced with toggle for message and global reactions
- Improve embed integration in presenter view

## v2.0.0

### Features

- Add dynamic layout in the manager view
- Add quick event feature
- Add question feature
- Add toggle for message reactions in attendees room
- Add toggle for polls results in attendees room
- Add delete account button in user settings
- Add language switcher in user settings
- Add tour guide for new users
- Add headers to exported CSV in reports
- Add spanish locale (#84) (@eduproinf)

### Fixes and improvements

- Improve Docker image to support both ARM and AMD64 architecture
- Change date picker for a more user-friendly one
- Upgrade Ecto, Phoenix and LiveView
- Fix user avatars in reports
- Fix average voters stats
- Fix some UI/UX issues
- Remove end date for events
- Replace `ENDPOINT_PORT` and `ENDPOINT_HOST` with `BASE_URL` environment variable
- Add `SAME_SITE_COOKIE` and `SECURE_COOKIE` environment variables

## v1.7.0

- Add keyboard shortcuts to control settings (#64) (@Dhanus3133)
- Add embed (Youtube or any web content) as an interraction (#72) (@Dhanus3133)
- Add pinned messages (#62) (@haruncurak)
- Add reset password feature
- Add indication when a form is saved
- Add Postmark adapter
- Add the ability to send mail to facilitators invited to manage an event
- Allow navigation within presenter window (#63) (@railsmechanic)
- Change default avatar style
- Security updates

## v1.6.0

- Improve QR code readability
- Add ARM Docker image
- Refactor all runtime configuration
- Improve local storage with PRESENTATION_STORAGE_DIR environment variable
- Fix poll/form panel scroll on mobile
- Fix message length validation
- Fix message word break
- Fix date translations
- Minor fixes on form management

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
