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
      loop: false,
      nav: false,
    });

    if (refresh) {
      return;
    }

    this.context.handleEvent("page", (data) => {
      //set current page
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
        e.preventDefault();

        switch (e.key) {
          case "f": // F
            this.fullscreen();
            break;
          case "ArrowUp":
            window.opener.dispatchEvent(
              new KeyboardEvent("keydown", { key: "ArrowUp" })
            );
            break;
          case "ArrowLeft":
            window.opener.dispatchEvent(
              new KeyboardEvent("keydown", { key: "ArrowLeft" })
            );
            break;
          case "ArrowRight":
            window.opener.dispatchEvent(
              new KeyboardEvent("keydown", { key: "ArrowRight" })
            );
            break;
          case "ArrowDown":
            window.opener.dispatchEvent(
              new KeyboardEvent("keydown", { key: "ArrowDown" })
            );
            break;
        }
      }
    });
  }

  update() {
    this.init(true);
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
