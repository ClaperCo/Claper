import { tns } from "tiny-slider";

export class Presenter {
  constructor(context) {
    this.context = context;
    this.currentPage = parseInt(context.el.dataset.currentPage);
    this.maxPage = parseInt(context.el.dataset.maxPage);
    this.hash = context.el.dataset.hash;
  }

  fitSlideArea() {
    const wrapper = document.getElementById("slides-join-wrapper");
    if (!wrapper) return;

    const img = document.querySelector("#slider .tns-item img, #slider img");
    if (!img || !img.naturalWidth || !img.naturalHeight) return;

    const ratio = img.naturalWidth / img.naturalHeight;
    const vh = window.innerHeight;

    // Determine how much width the join panel consumes
    const joinScreen = document.getElementById("joinScreen");
    const joinVisible = joinScreen && !joinScreen.classList.contains("hidden");

    // Total width available to the wrapper (the grid cell)
    const totalWidth = wrapper.parentElement.clientWidth;

    // Width the slide actually gets (exclude join panel)
    const slideWidth = joinVisible ? totalWidth * 0.8 : totalWidth;

    // Height that matches the slide's aspect ratio at its actual width
    let height = slideWidth / ratio;
    // Cap at viewport height
    height = Math.min(height, vh);

    wrapper.style.height = height + "px";
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

    // Fit slide area once first image is loaded, then on every resize
    const firstImg = document.querySelector("#slider img");
    if (firstImg) {
      const doFit = () => this.fitSlideArea();
      if (firstImg.complete) {
        doFit();
      } else {
        firstImg.addEventListener("load", doFit, { once: true });
      }
      window.addEventListener("resize", doFit);
    }

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
      // Delay to let grid layout settle after chat panel animation
      setTimeout(() => this.fitSlideArea(), 350);
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
      const joinScreen = document.getElementById("joinScreen");
      if (!joinScreen) return;
      if (data.value) {
        joinScreen.classList.remove("hidden");
        joinScreen.classList.add("flex");
      } else {
        joinScreen.classList.remove("flex");
        joinScreen.classList.add("hidden");
      }
      // Recalculate after the layout shift
      requestAnimationFrame(() => this.fitSlideArea());
    });

    window.addEventListener("keyup", (e) => {
      if (e.target.tagName.toLowerCase() != "input") {

        switch (e.key) {
          case "f": // F
            e.preventDefault();
            this.fullscreen();
            break;
          case "ArrowLeft":
            e.preventDefault();
            window.opener.dispatchEvent(
              new KeyboardEvent("keydown", { key: "ArrowLeft" })
            );
            break;
          case "ArrowRight":
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
