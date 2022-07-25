
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/ClaperCo/Claper">
    <img src="priv/static/images/logo.png" alt="Logo" >
  </a>

  <h3 align="center">Claper</h3>

  <p align="center">
    The ultimate tool to interact with your audience.
    <br />
    <a href="https://github.com/ClaperCo/Claper"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/ClaperCo/Claper/issues">Report Bug</a>
    ·
    <a href="https://github.com/ClaperCo/Claper/issues">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#configuration">Configuration</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

[![Product Name Screen Shot][product-screenshot]](https://claper.co)

Claper turns your presentations into an interactive, engaging and exciting experience.

Claper has a two-sided mission:
- The first one is to help these people presenting an idea or a message by giving them the opportunity to make their presentation unique and to have real-time feedback from their audience.
- The second one is to help each participant to take their place, to be an actor in the presentation, in the meeting and to feel important and useful.


### Built With

Claper is proudly powered by Phoenix and Elixir.

* [![Phoenix][Phoenix]][Phoenix-url]
* [![Elixir][Elixir]][Elixir-url]
* [![Tailwind][Tailwind]][Tailwind-url]


<!-- GETTING STARTED -->
## Getting Started

This is an example of how you may give instructions on setting up your project locally.
To get a local copy up and running follow these simple example steps.

### Prerequisites

To run Claper on your local environment you need to have:
* Postgres >= 9
* Elixir >= 1.13.2
* Erland >= 24
* NPM >= 6.14.17
* NodeJS >= 14.19.2
* Ghostscript >= 9.5.0 (for PDF support)
* Libreoffice >= 6.4 (for PPT/PPTX support)

You can also use Docker to easily run a Postgres instance:
```sh
  docker run -p 5432:5432 -e POSTGRES_PASSWORD=claper -e POSTGRES_USER=claper -e POSTGRES_DB=claper --name claper-db -d postgres:9
  ```

### Configuration

All configuration used by the app is store on the `.env` file. You can find an example file in `.env.sample`, but you should copy it to `.env` and fill it with your own values.

Variable | Values | Default | Description
--- | --- | --- | ---
DATABASE_URL | - | postgres://claper:claper@localhost:5432/postgres | Postgres connection string
SECRET_KEY_BASE | - | - | _(only for production)_  Generate it with `mix phx.gen.secret`
PRESENTATION_STORAGE | local, s3 | local | Define where the presentation files will be stored
MAIL | local, smtp | local | Define how the mails will be sent
AWS_ACCESS_KEY_ID | - | - | _(only if s3 is used)_ Your AWS Access Key ID
AWS_SECRET_ACCESS_KEY | - | - | _(only if s3 is used)_ Your AWS Secret Access Key
AWS_S3_BUCKET | - | - | _(only if s3 is used)_ The name of the bucket where the presentation files will be stored
AWS_S3_REGION | - | - | _(only if s3 is used)_ The region where the bucket is located

- **PRESENTATION_STORAGE** : `local` or `s3`, define where the presentation files will be stored.
- **MAIL** : `local` or `smtp`, define how the mails will be sent.

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/ClaperCo/Claper.git
   ```
2. Install dependencies
   ```sh
   mix deps.get
   ```
3. Migrate your database
   ```sh
   mix ecto.migrate
   ```
4. Install JS dependencies
   ```sh
   cd assets && npm i
   ```
5. Allow execution of startup file
   ```sh
   chmod +x ./start.sh
   ```
6. Start Phoenix endpoint with
   ```sh
   ./start.sh
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

If you have configured `MAIL` to `local`, you can access to the mailbox at [`localhost:4000/dev/mailbox`](http://localhost:4000/dev/mailbox).


#### Using Docker

You can build the app with Docker:
```sh
  docker build -t claper .
  docker run -p 4000:4000 -d claper
  ```


<!-- USAGE EXAMPLES -->
## Usage

### Login/Signup
Claper is passwordless, so you don't have to create an account. Just login with your email, check your mailbox ([localhost:4000/dev/mailbox](http://localhost:4000/dev/mailbox) if you have configured mail to be in local) and click on the link to get connected.

<!-- ROADMAP -->
## Roadmap

- [ ] Add Changelog
- [ ] Remove dead code
- [ ] Add additional tests for better coverage
- [ ] Add more docs

See the [open issues](https://github.com/ClaperCo/Claper/issues) for a full list of proposed features (and known issues).


<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


<!-- LICENSE -->
## License

Distributed under the GPLv3 License. See `LICENSE.txt` for more information.

<!-- CONTACT -->
## Contact

[![](https://img.shields.io/badge/@alexlionco-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/alexlionco) 

Project Link: [https://github.com/ClaperCo/Claper](https://github.com/ClaperCo/Claper)



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/ClaperCo/Claper.svg?style=for-the-badge
[contributors-url]: https://github.com/ClaperCo/Claper/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/ClaperCo/Claper.svg?style=for-the-badge
[forks-url]: https://github.com/ClaperCo/Claper/network/members
[stars-shield]: https://img.shields.io/github/stars/ClaperCo/Claper.svg?style=for-the-badge
[stars-url]: https://github.com/ClaperCo/Claper/stargazers
[issues-shield]: https://img.shields.io/github/issues/ClaperCo/Claper.svg?style=for-the-badge
[issues-url]: https://github.com/ClaperCo/Claper/issues
[license-shield]: https://img.shields.io/github/license/ClaperCo/Claper.svg?style=for-the-badge
[license-url]: https://github.com/ClaperCo/Claper/blob/master/LICENSE.txt
[product-screenshot]: /priv/static/images/preview.png
[Elixir]: https://img.shields.io/badge/elixir-4B275F?style=for-the-badge&logo=elixir&logoColor=white
[Elixir-url]: https://elixir-lang.org/
[Tailwind]: https://img.shields.io/badge/tailwind-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white
[Tailwind-url]: https://tailwindcss.com/
[Phoenix]: https://img.shields.io/badge/phoenix-f35424?style=for-the-badge&logo=&logoColor=white
[Phoenix-url]: https://www.phoenixframework.org/
