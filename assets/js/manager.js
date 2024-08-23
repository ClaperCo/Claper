import { tns } from "tiny-slider";

export class Manager {
  constructor(context) {
    this.context = context;
    this.currentPage = parseInt(context.el.dataset.currentPage);
    this.maxPage = parseInt(context.el.dataset.maxPage);
  }

  init() {
    this.context.handleEvent("page-manage", (data) => {
      var el = document.getElementById("slide-preview-" + data.current_page);

      if (el) {
        setTimeout(
          () => {
            const slidesLayout = document.getElementById("slides-layout");
            const layoutWidth = slidesLayout.clientWidth;
            const elementWidth = el.children[0].scrollWidth;
            const scrollPosition =
              el.children[0].offsetLeft - layoutWidth / 2 + elementWidth / 2;

            slidesLayout.scrollTo({
              left: scrollPosition,
            });
          },
          data.timeout ? data.timeout : 0
        );
      }
    });

    window.addEventListener("keydown", (e) => {
      if ((e.target.tagName || "").toLowerCase() != "input") {
        e.preventDefault();

        switch (e.key) {
          case "ArrowUp":
            this.prevPage();
            break;
          case "ArrowLeft":
            this.prevPage();
            break;
          case "ArrowRight":
            this.nextPage();
            break;
          case "ArrowDown":
            this.nextPage();
            break;
        }
      }
    });

    this.initPreview();
  }

  initPreview() {
    var preview = document.getElementById("preview");

    if (preview) {
      let isDragging = false;
      let startX, startY;

      let originalSnap = localStorage.getItem("preview-position");
      if (originalSnap) {
        let snaps = originalSnap.split(":");
        preview.style.left = `${snaps[0]}px`;
        preview.style.top = `${snaps[1]}px`;
      }

      const startDrag = (e) => {
        isDragging = true;
        startX = (e.clientX || e.touches[0].clientX) - preview.offsetLeft;
        startY = (e.clientY || e.touches[0].clientY) - preview.offsetTop;
      };

      const drag = (e) => {
        if (!isDragging) return;

        e.preventDefault();

        const clientX = e.clientX || e.touches[0].clientX;
        const clientY = e.clientY || e.touches[0].clientY;

        const newX = clientX - startX;
        const newY = clientY - startY;

        preview.style.left = `${newX}px`;
        preview.style.top = `${newY}px`;
      };

      const endDrag = () => {
        if (!isDragging) return;
        isDragging = false;

        const windowWidth = window.innerWidth;
        const windowHeight = window.innerHeight;
        const previewRect = preview.getBoundingClientRect();
        const padding = 20; // Add 20px padding

        let snapX, snapY;

        if (previewRect.left < windowWidth / 2) {
          snapX = padding;
        } else {
          snapX = windowWidth - previewRect.width - padding;
        }

        if (previewRect.top < windowHeight / 2) {
          snapY = padding;
        } else {
          snapY = windowHeight - previewRect.height - padding;
        }

        preview.style.transition = "left 0.3s ease-out, top 0.3s ease-out";
        preview.style.left = `${snapX}px`;
        preview.style.top = `${snapY}px`;

        localStorage.setItem("preview-position", `${snapX}:${snapY}`);

        // Remove the transition after it's complete
        setTimeout(() => {
          preview.style.transition = "";
        }, 300);
      };

      preview.addEventListener("mousedown", startDrag);
      preview.addEventListener("touchstart", startDrag);

      document.addEventListener("mousemove", drag);
      document.addEventListener("touchmove", drag);

      document.addEventListener("mouseup", endDrag);
      document.addEventListener("touchend", endDrag);
    }
  }

  update() {
    this.currentPage = parseInt(this.context.el.dataset.currentPage);
    var el = document.getElementById("slide-preview-" + this.currentPage);

    if (el) {
      setTimeout(() => {
        const slidesLayout = document.getElementById("slides-layout");
        const layoutWidth = slidesLayout.clientWidth;
        const elementWidth = el.children[0].scrollWidth;
        const scrollPosition =
          el.children[0].offsetLeft - layoutWidth / 2 + elementWidth / 2;

        slidesLayout.scrollTo({
          left: scrollPosition,
          behavior: "smooth",
        });
      }, 50);
    }

    this.initPreview();
  }

  nextPage() {
    if (this.currentPage == this.maxPage - 1) return;

    this.currentPage += 1;
    this.context.pushEventTo(this.context.el, "current-page", {
      page: this.currentPage.toString(),
    });
  }

  prevPage() {
    if (this.currentPage == 0) return;

    this.currentPage -= 1;
    this.context.pushEventTo(this.context.el, "current-page", {
      page: this.currentPage.toString(),
    });
  }
}
