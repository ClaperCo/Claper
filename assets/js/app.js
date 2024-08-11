// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket, Presence } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import Alpine from "alpinejs";
import moment from "moment-timezone";
import AirDatepicker from "air-datepicker";
import airdatepickerLocaleEn from "air-datepicker/locale/en";
import airdatepickerLocaleFr from "air-datepicker/locale/fr";
import airdatepickerLocaleDe from "air-datepicker/locale/de";
import airdatepickerLocaleEs from "air-datepicker/locale/es";
import airdatepickerLocaleNl from "air-datepicker/locale/nl";
import "moment/locale/de";
import "moment/locale/fr";
import "moment/locale/es";
import "moment/locale/nl";
import QRCodeStyling from "qr-code-styling";
import { Presenter } from "./presenter";
import { Manager } from "./manager";
import Split from "split-grid";
import { TourGuideClient } from "@sjmc11/tourguidejs/src/Tour";
window.moment = moment;

const supportedLocales = ["en", "fr", "de", "es", "nl"];

var locale =
  document.querySelector("html").getAttribute("lang") ||
  navigator.language.split("-")[0];

if (!supportedLocales.includes(locale)) {
  locale = "en";
}

window.moment.locale("en");
window.moment.locale(locale);
window.Alpine = Alpine;
Alpine.start();

let airdatepickerLocale = {
  en: airdatepickerLocaleEn,
  fr: airdatepickerLocaleFr,
  de: airdatepickerLocaleDe,
  es: airdatepickerLocaleEs,
  nl: airdatepickerLocaleNl,
};
let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let Hooks = {};

Hooks.EmbeddedBanner = {
  mounted() {
    if (window !== window.parent) {
      this.el.classList.remove("hidden");
    }
  },
  updated() {
    if (window !== window.parent) {
      this.el.classList.remove("hidden");
    }
  },
};

Hooks.TourGuide = {
  mounted() {
    this.tour = new TourGuideClient({
      nextLabel: this.el.dataset.nextLabel,
      prevLabel: this.el.dataset.prevLabel,
      finishLabel: this.el.dataset.finishLabel,
      completeOnFinish: true,
      rememberStep: true,
    });

    if (!this.tour.isFinished(this.el.dataset.group)) {
      this.tour.start(this.el.dataset.group);
    }

    this.tour.onBeforeExit(() => {
      this.tour.finishTour(true, this.el.dataset.group);
    });
  },
};

Hooks.Split = {
  mounted() {
    const type = this.el.dataset.type;
    const id = this.el.id;
    const gutter = this.el.dataset.gutter;
    const forceLayout = this.el.classList.contains("grid-cols-[1fr]");
    const columnSlitValue =
      localStorage.getItem(`column-split-${id}`) || "1fr 10px 1fr";
    const rowSlitValue =
      localStorage.getItem(`row-split-${id}`) || "1fr 10px 1fr";

    if (type === "column") {
      this.columnSplit = Split({
        columnGutters: [
          {
            track: 1,
            element: this.el.querySelector(gutter),
          },
        ],
        onDragEnd: () => {
          const currentPosition = this.el.style["grid-template-columns"];
          localStorage.setItem(`column-split-${id}`, currentPosition);
        },
      });
      if (!forceLayout) {
        this.el.style["grid-template-columns"] = columnSlitValue;
      }
    } else {
      this.rowSplit = Split({
        rowGutters: [
          {
            track: 1,
            element: this.el.querySelector(gutter),
          },
        ],
        onDragEnd: () => {
          const value = this.el.style["grid-template-rows"];
          localStorage.setItem(`row-split-${id}`, value);
        },
      });
      if (!forceLayout) {
        this.el.style["grid-template-rows"] = rowSlitValue;
      }
    }
  },
  updated() {
    const id = this.el.id;
    const forceLayout = this.el.classList.contains("grid-cols-[1fr]");
    if (forceLayout) {
      return;
    }

    this.mounted();
  },
  destroyed() {
    if (this.columnSplit) {
      this.columnSplit.destroy();
    }
    if (this.rowSplit) {
      this.rowSplit.destroy();
    }
  },
};

Hooks.Scroll = {
  mounted() {
    if (this.el.dataset.postsNb > 4)
      window.scrollTo({
        top: document.querySelector(this.el.dataset.target).scrollHeight,
        behavior: "smooth",
      });
    this.handleEvent("scroll", () => {});
  },
  updated() {
    let t = document.querySelector(this.el.dataset.target);
    if (
      this.el.childElementCount > 4 &&
      window.scrollY + window.innerHeight >= t.offsetHeight - 300
    ) {
      window.scrollTo({ top: t.scrollHeight, behavior: "smooth" });
    }
  },
};

Hooks.ScrollIntoDiv = {
  mounted() {
    this.scrollElement(true);
    this.handleEvent("scroll", this.scrollElement.bind(this));
  },
  scrollElement(firstScroll) {
    let t = this.el.parentElement;
    if (
      firstScroll === true ||
      t.scrollHeight - t.scrollTop - t.clientHeight <= 100
    ) {
      t.scrollTo({ top: t.scrollHeight, behavior: "smooth" });
    }
  },
};

Hooks.NicknamePicker = {
  mounted() {
    let currentNickname = localStorage.getItem("nickname") || "";
    if (currentNickname.length > 0) {
      this.pushEvent("set-nickname", { nickname: currentNickname });
    }

    this.el.addEventListener("click", (e) => this.clicked(e));
  },
  destroyed() {
    this.el.removeEventListener("click", (e) => this.clicked(e));
  },
  clicked(e) {
    let nickname = prompt(
      this.el.dataset.prompt,
      localStorage.getItem("nickname") || ""
    );

    if (nickname) {
      localStorage.setItem("nickname", nickname);
      this.pushEvent("set-nickname", { nickname: nickname });
    }
  },
};

Hooks.EmptyNickname = {
  mounted() {
    this.el.addEventListener("click", (e) => this.clicked(e));
  },
  destroyed() {
    this.el.removeEventListener("click", (e) => this.clicked(e));
  },
  clicked(e) {
    localStorage.removeItem("nickname");
  },
};

Hooks.PostForm = {
  onPress(e, submitBtn, TA) {
    if (e.key == "Enter" && !e.shiftKey) {
      e.preventDefault();
      submitBtn.click();
    } else {
      if (TA.value.length > 1 && TA.value.length < 256) {
        submitBtn.classList.remove("opacity-50");
        submitBtn.classList.add("opacity-100");
        submitBtn.disabled = false;
      } else {
        submitBtn.classList.add("opacity-50");
        submitBtn.classList.remove("opacity-100");
        submitBtn.disabled = true;
      }
    }
  },
  onSubmit(e, TA) {
    e.preventDefault();
    document.getElementById("hiddenSubmit").click();
    TA.value = "";
  },
  mounted() {
    setTimeout(() => {
      const submitBtn = document.getElementById("submitBtn");
      const TA = document.getElementById("postFormTA");
      if (submitBtn && TA) {
        submitBtn.addEventListener("click", (e) => this.onSubmit(e, TA));
        TA.addEventListener("keydown", (e) => this.onPress(e, submitBtn, TA));
      }
    }, 500);

    // set nickname if present
    let nickname = this.el.dataset.nickname;
    if (nickname) {
      localStorage.setItem("nickname", nickname);
    }
  },
  updated() {
    const submitBtn = document.getElementById("submitBtn");
    const TA = document.getElementById("postFormTA");
    if (TA.value.length > 1 && TA.value.length < 256) {
      submitBtn.classList.remove("opacity-50");
      submitBtn.classList.add("opacity-100");
      submitBtn.disabled = false;
    } else {
      submitBtn.classList.add("opacity-50");
      submitBtn.classList.remove("opacity-100");
      submitBtn.disabled = true;
    }
  },
  destroyed() {
    const submitBtn = document.getElementById("submitBtn");
    const TA = document.getElementById("postFormTA");
    if (submitBtn && TA) {
      TA.removeEventListener("keydown", (e) => this.onPress(e, submitBtn, TA));
      submitBtn.removeEventListener("click", (e) => this.onSubmit(e, TA));
    }
  },
};

Hooks.CalendarLocalDate = {
  mounted() {
    this.el.innerHTML = moment.utc(this.el.dataset.date).local().calendar();
  },
  updated() {
    this.el.innerHTML = moment.utc(this.el.dataset.date).local().calendar();
  },
};
Hooks.Pickr = {
  mounted() {
    const localTime = this.el.querySelector("input[type=text]");
    const utcTime = this.el.querySelector("input[type=hidden]");
    localTime.value = moment
      .utc(utcTime.value)
      .local()
      .format("DD-MM-YYYY HH:mm");
    this.pickr = new AirDatepicker(localTime, {
      dateFormat: "dd-MM-yyyy",
      timepicker: true,
      minutesStep: 5,
      minDate: moment(),
      timeFormat: "HH:mm",
      selectedDates: [moment(localTime.value, "DD-MM-YYYY HH:mm").toDate()],
      onSelect: ({ date }) => {
        const utc = moment(date).utc().format("YYYY-MM-DDTHH:mm:ss");
        utcTime.value = utc;
      },
      locale: airdatepickerLocale[locale],
    });
  },
  updated() {},
  destroyed() {
    this.pickr.destroy();
  },
};
Hooks.Presenter = {
  mounted() {
    this.presenter = new Presenter(this);
    this.presenter.init();
  },
  updated() {
    this.presenter.update();
  },
};
Hooks.Manager = {
  mounted() {
    this.manager = new Manager(this);
    this.manager.init();
  },
  updated() {
    this.manager.update();
  },
};
Hooks.OpenPresenter = {
  open(e) {
    e.preventDefault();
    window.open(
      this.el.dataset.url,
      "newwindow",
      "width=" + window.screen.width + ",height=" + window.screen.height
    );
  },
  mounted() {
    this.el.addEventListener("click", (e) => this.open(e));
  },
  updated() {
    this.el.removeEventListener("click", (e) => this.open(e));
    this.el.addEventListener("click", (e) => this.open(e));
  },
  destroyed() {
    this.el.removeEventListener("click", (e) => this.open(e));
  },
};
Hooks.GlobalReacts = {
  mounted() {
    this.handleEvent("global-react", (data) => {
      var img = document.createElement("img");
      img.src = "/images/icons/" + data.type + ".svg";
      img.className =
        "react-animation absolute transform opacity-0" + this.el.className;
      this.el.appendChild(img);
    });
    this.handleEvent("reset-global-react", (data) => {
      this.el.innerHTML = "";
    });
  },
};
Hooks.JoinEvent = {
  mounted() {
    const loading = document.getElementById("loading");
    const submit = document.getElementById("submit");
    const input = document.getElementById("input");

    submit.addEventListener("click", (e) => {
      if (input.value.length > 0) {
        submit.style.display = "none";
        loading.style.display = "block";
      }
    });
  },
  destroyed() {
    const loading = document.getElementById("loading");
    const submit = document.getElementById("submit");
    const input = document.getElementById("input");

    submit.removeEventListener("click", (e) => {
      if (input.value.length > 0) {
        submit.style.display = "none";
        loading.style.display = "block";
      }
    });
  },
};
Hooks.WelcomeEarly = {
  mounted() {
    if (localStorage.getItem("welcome-early") !== "false") {
      this.el.style.display = "block";
      this.el.children[0].addEventListener("click", (e) => {
        e.preventDefault();
        localStorage.setItem("welcome-early", "false");
        this.el.style.display = "none";
      });
    }
  },
  destroyed() {
    this.el.children[0].removeEventListener("click", (e) => {
      e.preventDefault();
      localStorage.setItem("welcome-early", "false");
      this.el.style.display = "none";
    });
  },
};
Hooks.ClickFeedback = {
  clicked(e) {
    this.el.className = "animate__animated animate__rubberBand animate__faster";
    setTimeout(() => {
      this.el.className = "";
    }, 500);
  },
  mounted() {
    this.el.addEventListener("click", (e) => this.clicked(e));
  },
  destroyed() {
    this.el.removeEventListener("click", (e) => this.clicked(e));
  },
};
Hooks.QRCode = {
  draw() {
    var url = this.el.dataset.code
      ? window.location.protocol +
        "//" +
        window.location.host +
        "/e/" +
        this.el.dataset.code
      : window.location.href;
    this.el.style.width = document.documentElement.clientWidth * 0.27 + "px";
    this.el.style.height = document.documentElement.clientWidth * 0.27 + "px";

    if (this.qrCode == null) {
      this.qrCode = new QRCodeStyling({
        width: this.el.dataset.dynamic
          ? document.documentElement.clientWidth * 0.25
          : 240,
        height: this.el.dataset.dynamic
          ? document.documentElement.clientWidth * 0.25
          : 240,
        margin: 0,
        data: url,
        cornersSquareOptions: {
          type: "square",
        },
        dotsOptions: {
          type: "square",
          color: "#ffffff",
        },
        backgroundOptions: {
          color: "#000000",
        },
        imageOptions: {
          crossOrigin: "anonymous",
          imageSize: 0.6,
          margin: 10,
        },
      });
      this.qrCode.append(this.el);
    } else {
      this.qrCode.update({
        width: this.el.dataset.dynamic
          ? document.documentElement.clientWidth * 0.25
          : 240,
        height: this.el.dataset.dynamic
          ? document.documentElement.clientWidth * 0.25
          : 240,
      });
    }
  },
  mounted() {
    window.addEventListener("resize", this.draw.bind(this));
    this.draw();
    if (this.el.dataset.getUrl) {
      setTimeout(() => {
        var dataURL = this.qrCode._canvas.toDataURL();
        document.getElementById("qr-url").value = dataURL;
      }, 500);
    }
  },
  updated() {},
  destroyed() {},
};

Hooks.Dropdown = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      this.el.classList.toggle("hidden");
    });
  },
};

let Uploaders = {};

Uploaders.S3 = function (entries, onViewError) {
  entries.forEach((entry) => {
    let formData = new FormData();
    let { url, fields } = entry.meta;
    Object.entries(fields).forEach(([key, val]) => formData.append(key, val));
    formData.append("file", entry.file);
    let xhr = new XMLHttpRequest();
    onViewError(() => xhr.abort());
    xhr.onload = () =>
      xhr.status === 204 ? entry.progress(100) : entry.error();
    xhr.onerror = () => entry.error();
    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100);
        if (percent < 100) {
          entry.progress(percent);
        }
      }
    });

    xhr.open("POST", url, true);
    xhr.send(formData);
  });
};

let liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,
  params: {
    _csrf_token: csrfToken,
    tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
    host: window.location.host,
  },
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to);
        window.Alpine.initTree(to);
      }
    },
  },
});

// Show progress bar on live navigation and form submits
let topBarScheduled = undefined;
topbar.config({ barColors: { 0: "#fff" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (info) => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 500);
  }
});
window.addEventListener("phx:page-loading-stop", (info) => {
  clearTimeout(topBarScheduled);
  topBarScheduled = undefined;
  topbar.hide();
});

const renderOnlineUsers = function (presences) {
  let onlineUsers = Presence.list(
    presences,
    (_id, { metas: [user, ...rest] }) => {
      return onlineUserTemplate(user);
    }
  ).join("");

  document.querySelector("body").innerHTML = onlineUsers;
};

const onlineUserTemplate = function (user) {
  return `
    <div id="online-user">
      <strong class="text-secondary">aaa</strong>
    </div>
  `;
};

let presences = {};
liveSocket.on("presence_state", (state) => {
  presences = Presence.syncState(presences, state);
  renderOnlineUsers(presences);
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
