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
import airdatepickerLocaleIt from "air-datepicker/locale/it";
import airdatepickerLocaleHu from "air-datepicker/locale/hu";
import "moment/locale/de";
import "moment/locale/fr";
import "moment/locale/es";
import "moment/locale/nl";
import "moment/locale/it";
import "moment/locale/hu";
import "moment/locale/lv";
import QRCodeStyling from "qr-code-styling";
import { Presenter } from "./presenter";
import { Manager } from "./manager";
import Split from "split-grid";
import CustomHooks from "./hooks";
import { TourGuideClient } from "@sjmc11/tourguidejs/src/Tour";
import "./admin-charts.js";
window.moment = moment;

// Get supported locales from backend configuration or fallback to default list
const supportedLocales = window.claperConfig?.supportedLocales || [
  "en",
  "fr",
  "de",
  "es",
  "nl",
  "it",
  "hu",
  "lv",
];

const airdatePickrSupportedLocales = window.claperConfig?.supportedLocales || [
  "en",
  "fr",
  "de",
  "es",
  "nl",
  "it",
  "hu",
];

var locale =
  document.querySelector("html").getAttribute("lang") ||
  navigator.language.split("-")[0];

var airdatepickrLocale = locale;

if (!supportedLocales.includes(locale)) {
  locale = "en";
}
if (!airdatePickrSupportedLocales.includes(locale)) {
  airdatepickrLocale = "en";
}

window.moment.locale("en");
window.moment.locale(locale);
window.Alpine = Alpine;
Alpine.start();

let airdatePickrLocales = {
  en: airdatepickerLocaleEn,
  fr: airdatepickerLocaleFr,
  de: airdatepickerLocaleDe,
  es: airdatepickerLocaleEs,
  nl: airdatepickerLocaleNl,
  it: airdatepickerLocaleIt,
  hu: airdatepickerLocaleHu,
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
    this.triggerDiv = document.querySelector(this.el.dataset.btnTrigger);
    this.btnTrigger = this.triggerDiv.querySelector(".open");
    this.closeBtnTrigger = this.triggerDiv.querySelector(".close");

    this.tour = new TourGuideClient({
      nextLabel: this.el.dataset.nextLabel,
      prevLabel: this.el.dataset.prevLabel,
      finishLabel: this.el.dataset.finishLabel,
      completeOnFinish: true,
      rememberStep: true,
    });

    if (!this.tour.isFinished(this.el.dataset.group)) {
      this.triggerDiv.classList.remove("hidden");
    }

    this.tour.onBeforeExit(() => {
      this.tour.finishTour(true, this.el.dataset.group);
    });

    this.btnTrigger.addEventListener("click", () => {
      this.startTour();
    });

    this.closeBtnTrigger.addEventListener("click", (e) => {
      this.triggerDiv.classList.add("hidden");
      this.tour.finishTour(true, this.el.dataset.group);
    });
  },

  startTour() {
    this.triggerDiv.classList.add("hidden");
    this.tour.start(this.el.dataset.group);
  },
  destroyed() {
    this.btnTrigger.removeEventListener("click", () => {
      this.startTour();
    });
    this.closeBtnTrigger.removeEventListener("click", () => {
      this.triggerDiv.classList.add("hidden");
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
      localStorage.getItem(`row-split-${id}`) || "0.5fr 10px 1fr";

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
    let useParent = this.el.dataset.useParent === "true";
    this.scrollElement =
      this.el.dataset.useParent === "true" ? this.el.parentElement : this.el;
    this.checkIfAtBottom();
    this.scrollToBottom(true);
    this.handleEvent("scroll", () => this.scrollToBottom());
    this.scrollElement.addEventListener("scroll", () => this.checkIfAtBottom());
  },
  checkIfAtBottom() {
    this.isAtBottom =
      this.scrollElement.scrollHeight -
        this.scrollElement.scrollTop -
        this.scrollElement.clientHeight <=
      30;
  },
  scrollToBottom(force = false) {
    if (force || this.isAtBottom) {
      this.scrollElement.scrollTo({
        top: this.scrollElement.scrollHeight,
        behavior: "smooth",
      });
    }
  },
  updated() {
    this.scrollToBottom();
  },
  destroyed() {
    this.scrollElement.removeEventListener("scroll", () =>
      this.checkIfAtBottom(),
    );
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
  reconnected() {
    let currentNickname = localStorage.getItem("nickname") || "";
    if (currentNickname.length > 0) {
      this.pushEvent("set-nickname", { nickname: currentNickname });
    }
  },
  destroyed() {
    this.el.removeEventListener("click", (e) => this.clicked(e));
  },
  clicked(e) {
    let nickname = prompt(
      this.el.dataset.prompt,
      localStorage.getItem("nickname") || "",
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

Hooks.SearchableSelect = {
  mounted() {
    this.handleEvent("update_hidden_field", (payload) => {
      if (payload.id === this.el.id) {
        this.el.value = payload.value;
        // Trigger a change event to update the form
        const event = new Event('input', { bubbles: true });
        this.el.dispatchEvent(event);
      }
    });
  }
};

Hooks.PostForm = {
  onPress(e, submitBtn, TA) {
    if (e.key == "Enter" && !e.shiftKey) {
      e.preventDefault();
      submitBtn.click();
    } else {
      if (TA.value.length > 0 && TA.value.length < 256) {
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
    if (TA.value.length > 0 && TA.value.length < 256) {
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
      locale: airdatePickrLocales[airdatepickrLocale],
    });
  },
  updated() {},
  destroyed() {
    this.pickr.destroy();
  },
};
Hooks.UpdateAttendees = {
  mounted() {
    this.handleEvent("update-attendees", ({ count }) => {
      this.el.textContent = count;
    });
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
      "width=" + window.screen.width + ",height=" + window.screen.height,
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
  svgCache: {},

  mounted() {
    this.preloadSVGs();
    this.handleEvent("global-react", (data) => {
      const svgContent = this.svgCache[data.type];
      if (svgContent) {
        const container = document.createElement("div");
        container.innerHTML = svgContent;
        const svgElement = container.firstChild;
        svgElement.classList.add(
          "react-animation",
          "absolute",
          "transform",
          "opacity-0",
        );
        svgElement.classList.add(...this.el.className.split(" "));
        this.el.appendChild(svgElement);
      }
    });
    this.handleEvent("reset-global-react", (data) => {
      this.el.innerHTML = "";
    });
  },

  preloadSVGs() {
    const svgTypes = ["heart", "hundred", "clap", "raisehand"];
    svgTypes.forEach((type) => {
      fetch(`/images/icons/${type}.svg`)
        .then((response) => response.text())
        .then((svgContent) => {
          this.svgCache[type] = svgContent;
        })
        .catch((error) =>
          console.error(`Error loading SVG for ${type}:`, error),
        );
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
          color: "#000000",
        },
        backgroundOptions: {
          color: "#ffffff",
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

Hooks.AdminChart = {
  mounted() {
    const chartType = this.el.dataset.chartType;
    const canvasId = this.el.querySelector('canvas').id;
    const data = JSON.parse(this.el.dataset.chartData);
    
    if (chartType === 'users') {
      window.AdminCharts.createUsersChart(canvasId, data);
    } else if (chartType === 'events') {
      window.AdminCharts.createEventsChart(canvasId, data);
    }
    
    this.handleEvent("update_chart", (newData) => {
      window.AdminCharts.updateChart(canvasId, newData);
    });
  },
  
  updated() {
    const chartType = this.el.dataset.chartType;
    const canvasId = this.el.querySelector('canvas').id;
    const data = JSON.parse(this.el.dataset.chartData);
    
    if (chartType === 'users') {
      window.AdminCharts.createUsersChart(canvasId, data);
    } else if (chartType === 'events') {
      window.AdminCharts.createEventsChart(canvasId, data);
    }
  },
  
  destroyed() {
    const canvasId = this.el.querySelector('canvas').id;
    window.AdminCharts.destroyChart(canvasId);
  }
};

Hooks.CSVDownloader = {
  mounted() {
    this.handleEvent("download_csv", ({ filename, content }) => {
      const blob = new Blob([content], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    });
  }
};

// Merge our custom hooks with the existing hooks
Object.assign(Hooks, CustomHooks);

let liveSocket = new LiveSocket("/live", Socket, {
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
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
