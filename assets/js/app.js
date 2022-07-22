// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "./vendor/some-package.js"
//
// Alternatively, you can `npm install some-package` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket, Presence} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Alpine from 'alpinejs'
import flatpickr from "flatpickr"
import moment from "moment-timezone"
import QRCodeStyling from "qr-code-styling"
import { Presenter } from "./presenter"
import { Manager } from "./manager"
window.moment = moment


window.moment.locale('fr', {
  months : 'janvier_février_mars_avril_mai_juin_juillet_août_septembre_octobre_novembre_décembre'.split('_'),
  monthsShort : 'janv._févr._mars_avr._mai_juin_juil._août_sept._oct._nov._déc.'.split('_'),
  monthsParseExact : true,
  weekdays : 'dimanche_lundi_mardi_mercredi_jeudi_vendredi_samedi'.split('_'),
  weekdaysShort : 'dim._lun._mar._mer._jeu._ven._sam.'.split('_'),
  weekdaysMin : 'Di_Lu_Ma_Me_Je_Ve_Sa'.split('_'),
  weekdaysParseExact : true,
  longDateFormat : {
      LT : 'HH:mm',
      LTS : 'HH:mm:ss',
      L : 'DD/MM/YYYY',
      LL : 'D MMMM YYYY',
      LLL : 'D MMMM YYYY HH:mm',
      LLLL : 'dddd D MMMM YYYY HH:mm'
  },
  calendar : {
      sameDay : '[Aujourd’hui à] LT',
      nextDay : '[Demain à] LT',
      nextWeek : 'dddd [à] LT',
      lastDay : '[Hier à] LT',
      lastWeek : 'dddd [dernier à] LT',
      sameElse : 'L'
  },
  relativeTime : {
      future : 'dans %s',
      past : 'il y a %s',
      s : 'quelques secondes',
      m : 'une minute',
      mm : '%d minutes',
      h : 'une heure',
      hh : '%d heures',
      d : 'un jour',
      dd : '%d jours',
      M : 'un mois',
      MM : '%d mois',
      y : 'un an',
      yy : '%d ans'
  },
  dayOfMonthOrdinalParse : /\d{1,2}(er|e)/,
  ordinal : function (number) {
      return number + (number === 1 ? 'er' : 'e');
  },
  meridiemParse : /PD|MD/,
  isPM : function (input) {
      return input.charAt(0) === 'M';
  },
  // In case the meridiem units are not separated around 12, then implement
  // this function (look at locale/id.js for an example).
  // meridiemHour : function (hour, meridiem) {
  //     return /* 0-23 hour, given meridiem token and hour 1-12 */ ;
  // },
  meridiem : function (hours, minutes, isLower) {
      return hours < 12 ? 'PD' : 'MD';
  },
  week : {
      dow : 1, // Monday is the first day of the week.
      doy : 4  // Used to determine first week of the year.
  }
});
window.moment.locale(navigator.languages[0].split('-')[0])


window.Alpine = Alpine
Alpine.start()

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let Hooks = {}

Hooks.Scroll = {
  mounted() {
    if (this.el.dataset.postsNb > 4) window.scrollTo({top: document.querySelector(this.el.dataset.target).scrollHeight, behavior: 'smooth'});
    this.handleEvent("scroll", () => {
      let t = document.querySelector(this.el.dataset.target)
      if (this.el.childElementCount > 4 && (window.scrollY + window.innerHeight >= t.offsetHeight - 100)) {
       window.scrollTo({top: t.scrollHeight, behavior: 'smooth'});
      }
    })
  }
}

Hooks.ScrollIntoDiv = {
  mounted() {
    let t = document.querySelector(this.el.dataset.target)
    if (this.el.dataset.postsNb > 4) t.scrollTo({top: t.scrollHeight, behavior: 'smooth'});

    this.handleEvent("scroll", () => {
      let t = document.querySelector(this.el.dataset.target);
      if (this.el.childElementCount > 4 && (t.scrollHeight - t.scrollTop < t.clientHeight + 100)) {
        t.scrollTo({top: t.scrollHeight, behavior: 'smooth'});
      }
    })
  }
}

Hooks.PostForm = {
  onPress(e, submitBtn, TA) {
    if (e.key == "Enter" && !e.shiftKey) {
      e.preventDefault()
      submitBtn.click()
    } else {
      if (TA.value.length > 2) {
        submitBtn.classList.remove("opacity-50")
        submitBtn.classList.add("opacity-100")
      } else {
        submitBtn.classList.add("opacity-50")
        submitBtn.classList.remove("opacity-100")
      }
    }
  },
  onSubmit(e, TA) {
    e.preventDefault()
    document.getElementById("hiddenSubmit").click()
    TA.value = ""
  },
  mounted() {
    const submitBtn = document.getElementById("submitBtn")
    const TA = document.getElementById("postFormTA")
    submitBtn.addEventListener("click", (e) => this.onSubmit(e, TA))
    TA.addEventListener("keydown",  (e) => this.onPress(e, submitBtn, TA))
  },
  updated() {
    const submitBtn = document.getElementById("submitBtn")
    const TA = document.getElementById("postFormTA")
    if (TA.value.length > 2) {
      submitBtn.classList.remove("opacity-50")
      submitBtn.classList.add("opacity-100")
    } else {
      submitBtn.classList.add("opacity-50")
      submitBtn.classList.remove("opacity-100")
    }
  },
  destroyed() {
    const submitBtn = document.getElementById("submitBtn")
    const TA = document.getElementById("postFormTA")
    TA.removeEventListener("keydown",  (e) => this.onPress(e, submitBtn, TA))
    submitBtn.removeEventListener("click",  (e) => this.onSubmit(e, TA))
  }
}

Hooks.CalendarLocalDate = {
  mounted() {
    this.el.innerHTML = moment.utc(this.el.dataset.date).local().calendar()
  },
  updated() {
    this.el.innerHTML = moment.utc(this.el.dataset.date).local().calendar()
  }
}
Hooks.Pickr = {
  mounted() {
    const getDefaultDate = (dateStart, dateEnd, mode) => {
      if (mode == "range") {
        return moment.utc(dateStart).format('Y-MM-DD HH:mm') + " - " +  moment.utc(dateEnd).format('Y-MM-DD HH:mm')
      } else {
        return moment.utc(dateStart).format('Y-MM-DD HH:mm')
      }
    };
    this.pickr = flatpickr(this.el, {
      wrap: true,
      inline: false,
      enableTime: true,
      enable: JSON.parse(this.el.dataset.enable),
      time_24hr: true,
      formatDate: (date, format, locale) => {
        return moment(date).utc().format('Y-MM-DD HH:mm');
      },
      parseDate: (datestr, format) => {
        return moment.utc(datestr).local().toDate();
      },
      locale: {
        firstDayOfWeek: 1,
        rangeSeparator: ' - '
      },
      mode: this.el.dataset.mode == "range" ? "range" : "single",
      minuteIncrement: 1,
      dateFormat: "Y-m-d H:i",
      defaultDate: getDefaultDate(this.el.dataset.defaultDateStart, this.el.dataset.defaultDateEnd, this.el.dataset.mode)
    })
  },
  updated() {
  },
  destroyed() {
    this.pickr.destroy()
  }
}
Hooks.Presenter = {
  mounted() {
    this.presenter = new Presenter(this)
    this.presenter.init()
  }
}
Hooks.Manager = {
  mounted() {
    this.manager = new Manager(this)
    this.manager.init()
  },
  updated() {
    this.manager.update()
  }
}
Hooks.OpenPresenter = {
  open(e) {
    e.preventDefault()
      window.open(this.el.dataset.url, 'newwindow',
                'width=' + window.screen.width + ',height=' + window.screen.height)
  },
  mounted() {
    this.el.addEventListener("click", e => this.open(e))
  },
  updated() {
    this.el.removeEventListener("click", e => this.open(e))
    this.el.addEventListener("click", e => this.open(e))
  },
  destroyed() {
    this.el.removeEventListener("click", e => this.open(e))
  }
}
Hooks.GlobalReacts = {
  mounted() {

    this.handleEvent('global-react', data => {
      var img = document.createElement("img");
      img.src = "/images/icons/" + data.type + ".svg"
      img.className = "react-animation absolute transform opacity-0" + this.el.className
      this.el.appendChild(img)
    })
    this.handleEvent('reset-global-react', data => {
      this.el.innerHTML = ""
    })
  }
}
Hooks.JoinEvent = {
  mounted() {
    const loading = document.getElementById("loading")
    const submit = document.getElementById("submit")
    const input = document.getElementById("input")

    submit.addEventListener("click", (e) => {
      if (input.value.length > 0) {
        submit.style.display = "none"
        loading.style.display = "block"
      }
    })
  },
  destroyed() {
    const loading = document.getElementById("loading")
    const submit = document.getElementById("submit")
    const input = document.getElementById("input")

    submit.removeEventListener("click", (e) => {
      if (input.value.length > 0) {
        submit.style.display = "none"
        loading.style.display = "block"
      }
    })
  }
}
Hooks.WelcomeEarly = {
  mounted() {

    if (localStorage.getItem("welcome-early") !== "false") {
      this.el.style.display = "block"
      this.el.children[0].addEventListener("click", (e) => {
        e.preventDefault()
        localStorage.setItem("welcome-early", "false")
        this.el.style.display = "none"
      })
    }
    
  },
  destroyed() {
    this.el.children[0].removeEventListener("click", (e) => {
      e.preventDefault()
      localStorage.setItem("welcome-early", "false")
      this.el.style.display = "none"
    })
  }
}
Hooks.DefaultValue = {
  mounted() {
    this.el.value = moment(this.el.dataset.defaultValue ? this.el.dataset.defaultValue : undefined).utc().format();
  }
}
Hooks.ClickFeedback = {
  clicked(e) {
    this.el.className = "animate__animated animate__rubberBand animate__faster";
    setTimeout(() => {
      this.el.className = "";
    } , 500);
  },
  mounted() {
    this.el.addEventListener("click", (e) => this.clicked(e))
  },
  destroy() {
    this.el.removeEventListener("click", (e) => this.clicked(e))
  }
}
Hooks.QRCode = {
  draw() {
    var url = this.el.dataset.code ? window.location.protocol + "//" + window.location.host + "/e/" +  this.el.dataset.code : window.location.href;
    this.el.style.width = document.documentElement.clientWidth * .27 + "px"
    this.el.style.height = document.documentElement.clientWidth * .27 + "px"

    if (this.qrCode == null) {
      this.qrCode = new QRCodeStyling({
        width: this.el.dataset.dynamic ? document.documentElement.clientWidth * .25 : 240,
        height: this.el.dataset.dynamic ? document.documentElement.clientWidth * .25 : 240,
        margin: 0,
        image:
          "/images/logo.png",
        data: url,
        cornersSquareOptions: {
          type: "square"
        },
        dotsOptions: {
          type: "square",
          gradient: {
            type: "linear",
            rotation: Math.PI * 0.2,
            colorStops: [{
              offset: 0,
              color: '#14bfdb'
            }, {
              offset: 1,
              color: '#b80fef'
            }]}
        },
        imageOptions: {
          crossOrigin: "anonymous",
          imageSize: 0.6,
          margin: 10
        }
      })
      this.qrCode.append(this.el)
    } else {
      this.qrCode.update({
        width: this.el.dataset.dynamic ? document.documentElement.clientWidth * .25 : 240,
        height: this.el.dataset.dynamic ? document.documentElement.clientWidth * .25 : 240
      })
    }

  },
  mounted() {
    window.addEventListener("resize", this.draw.bind(this));
    this.draw()
    if (this.el.dataset.getUrl) {
      setTimeout(() => {
        var dataURL = this.qrCode._canvas.toDataURL()
        document.getElementById("qr-url").value = dataURL
      }, 500);  
    }
  },
  updated() {
  },
  destroyed() {
  }
}

let Uploaders = {}

Uploaders.S3 = function(entries, onViewError){
  entries.forEach(entry => {
    let formData = new FormData()
    let {url, fields} = entry.meta
    Object.entries(fields).forEach(([key, val]) => formData.append(key, val))
    formData.append("file", entry.file)
    let xhr = new XMLHttpRequest()
    onViewError(() => xhr.abort())
    xhr.onload = () => xhr.status === 204 ? entry.progress(100) : entry.error()
    xhr.onerror = () => entry.error()
    xhr.upload.addEventListener("progress", (event) => {
      if(event.lengthComputable){
        let percent = Math.round((event.loaded / event.total) * 100)
        if(percent < 100){ entry.progress(percent) }
      }
    })

    xhr.open("POST", url, true)
    xhr.send(formData)
  })
}


let liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,
  params: {_csrf_token: csrfToken, tz: Intl.DateTimeFormat().resolvedOptions().timeZone},
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to){
      if(from._x_dataStack){ 
        window.Alpine.clone(from, to)
        window.Alpine.initTree(to)
      }
    }
  },})

// Show progress bar on live navigation and form submits
let topBarScheduled = undefined
topbar.config({barColors: {0: "#fff"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => {
  if(!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 500)
  }
})
window.addEventListener("phx:page-loading-stop", info => {
  clearTimeout(topBarScheduled)
  topBarScheduled = undefined
  topbar.hide()
})

const renderOnlineUsers = function(presences) {
  let onlineUsers = Presence.list(presences, (_id, {metas: [user, ...rest]}) => {
    return onlineUserTemplate(user);
  }).join("")

  document.querySelector("body").innerHTML = onlineUsers;
}

const onlineUserTemplate = function(user) {
  return `
    <div id="online-user">
      <strong class="text-secondary">aaa</strong>
    </div>
  `
}

let presences = {};
liveSocket.on("presence_state", state => {
  presences = Presence.syncState(presences, state)
  renderOnlineUsers(presences)
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket