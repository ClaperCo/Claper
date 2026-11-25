import { tns } from "tiny-slider";

export class Presenter {
  constructor(context) {
    this.context = context;
    this.currentPage = parseInt(context.el.dataset.currentPage);
    this.maxPage = parseInt(context.el.dataset.maxPage);
    this.hash = context.el.dataset.hash;
  }

  init(refresh = false) {
    this.slider = tns({
      container: "#slider",
      items: 1,
      mode: "gallery",
      slideBy: "page",
      center: true,
      autoplay: false,
      controls: false,
      swipeAngle: false,
      startIndex: this.currentPage,
      speed: 0,
      loop: false,
      nav: false,
    });

    if (refresh) {
      return;
    }

    this.context.handleEvent("page", (data) => {
      //set current page
      if (this.currentPage == data.current_page) {
        return;
      }

      this.currentPage = parseInt(data.current_page);
      this.slider.goTo(data.current_page);

    });

    this.context.handleEvent("chat-visible", (data) => {
      if (data.value) {
        document
          .getElementById("post-list")
          .classList.remove("animate__animated", "animate__fadeOutLeft");
        document
          .getElementById("post-list")
          .classList.add("animate__animated", "animate__fadeInLeft");

        document
          .getElementById("pinned-post-list")
          .classList.remove("animate__animated", "animate__fadeOutLeft");
        document
          .getElementById("pinned-post-list")
          .classList.add("animate__animated", "animate__fadeInLeft");
      } else {
        document
          .getElementById("post-list")
          .classList.remove("animate__animated", "animate__fadeInLeft");
        document
          .getElementById("post-list")
          .classList.add("animate__animated", "animate__fadeOutLeft");

        document
          .getElementById("pinned-post-list")
          .classList.remove("animate__animated", "animate__fadeInLeft");
        document
          .getElementById("pinned-post-list")
          .classList.add("animate__animated", "animate__fadeOutLeft");
      }
    });

    this.context.handleEvent("poll-visible", (data) => {
      if (data.value) {
        document
          .getElementById("poll")
          .classList.remove("animate__animated", "animate__fadeOut");
        document
          .getElementById("poll")
          .classList.add("animate__animated", "animate__fadeIn");
      } else {
        document
          .getElementById("poll")
          .classList.remove("animate__animated", "animate__fadeIn");
        document
          .getElementById("poll")
          .classList.add("animate__animated", "animate__fadeOut");
      }
    });

    this.context.handleEvent("join-screen-visible", (data) => {
      if (data.value) {
        document
          .getElementById("joinScreen")
          .classList.remove("animate__animated", "animate__fadeOut");
        document
          .getElementById("joinScreen")
          .classList.add("animate__animated", "animate__fadeIn");
      } else {
        document
          .getElementById("joinScreen")
          .classList.remove("animate__animated", "animate__fadeIn");
        document
          .getElementById("joinScreen")
          .classList.add("animate__animated", "animate__fadeOut");
      }
    });

    window.addEventListener("keyup", (e) => {
      if (e.target.tagName.toLowerCase() != "input") {

        switch (e.key) {
          case "f": // F
            e.preventDefault();
            this.fullscreen();
            break;
          case "c": // C: review the quiz questions on/off
          case "C":
            if (e.ctrlKey || e.metaKey || e.altKey) break;
            e.preventDefault();
            this.context.pushEvent("toggle-quiz-review", {});
            break;
          case "ArrowLeft":
          case "PageUp":
            e.preventDefault();
            window.opener.dispatchEvent(
              new KeyboardEvent("keydown", { key: "ArrowLeft" })
            );
            break;
          case "ArrowRight":
          case "PageDown":
            e.preventDefault();
            window.opener.dispatchEvent(
              new KeyboardEvent("keydown", { key: "ArrowRight" })
            );
            break;
        }
      }
    });

    window.addEventListener("storage", (e) => {
      console.log(e)
      if (e.key == "slide-position") {
        console.log("settings new value " + Date.now())
        this.currentPage = parseInt(e.newValue);
        this.slider.goTo(e.newValue);

      }
    })
  }

  update() {
    const newHash = this.context.el.dataset.hash;
    const newMaxPage = parseInt(this.context.el.dataset.maxPage);
    const newPage = parseInt(this.context.el.dataset.currentPage);
    const embedActive = this.context.el.dataset.embedActive === "true";

    // Toggle slider visibility for embeds (phx-update="ignore" prevents LiveView from doing it)
    const sliderEl = document.getElementById("slider");
    if (sliderEl) {
      if (embedActive) {
        sliderEl.classList.add("hidden");
      } else {
        sliderEl.classList.remove("hidden");
      }
    }

    if (newHash !== this.hash || newMaxPage !== this.maxPage) {
      // Presentation file changed — full re-init needed
      this.hash = newHash;
      this.maxPage = newMaxPage;
      this.currentPage = newPage;
      this.init(true);
    } else if (newPage !== this.currentPage) {
      // Just a page change — navigate without re-init
      this.currentPage = newPage;
      this.slider.goTo(newPage);
    }
    // Otherwise: unrelated DOM update (e.g. transcription text) — do nothing
  }

  fullscreen() {
    var docEl = document.getElementById("presenter");

    try {
      docEl
        .webkitRequestFullscreen()
        .then(function () {})
        .catch(function (error) {});
    } catch (e) {
      docEl
        .requestFullscreen()
        .then(function () {})
        .catch(function (error) {});

      docEl
        .mozRequestFullScreen()
        .then(function () {})
        .catch(function (error) {});
    }
  }
}
