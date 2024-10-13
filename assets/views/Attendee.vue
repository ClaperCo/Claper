<template>
  <div class="relative min-h-screen lg:flex lg:flex-col lg:items-center lg:w-full bg-black lg:bg-gradient-to-tl from-primary-500 to-secondary-500">
    <div class="relative w-full">
      <div
        id="side-menu-shadow"
        @click="sideMenu = false"
        class="hidden fixed z-20 h-screen bg-black bg-opacity-70 w-full"
      >
      </div>

      <div
        id="side-menu"
        :if="sideMenu && event"
        class="fixed h-screen w-64 bg-white rounded-r-lg flex z-30 px-4 flex-col justify-start lg:left-0"
      >
        <div>
          <img src="/images/logo-large-black.svg" class="h-16 my-3" />

          <span class="font-bold text-xl">{{ event.name }}</span>
        </div>

        <a
          class="flex items-center px-3 py-2 bg-gray-200 mb-15 rounded-lg mt-5"
          href=""
        >
          <img src="/images/icons/exit-outline.svg" class="h-5 mr-3" />
          <span>Leave</span>
        </a>
      </div>
    </div>

    <div
      id="content"
      class="w-full bg-black fixed z-10 lg:w-1/3"
      style="box-shadow: 0px 15px 14px 1px rgba(0,0,0,0.75); -webkit-box-shadow: 0px 15px 14px 1px rgba(0,0,0,0.75); -moz-box-shadow: 0px 15px 14px 1px rgba(0,0,0,0.75);"
    >
      <div id="banner" class="hidden w-full bg-gray-800 text-center" phx-hook="EmbeddedBanner">
        <a href="https://claper.co" target="_blank" class="text-xs text-white py-3 w-full">
          Create your next presentation with
          <span class="underline">Claper</span>
        </a>
      </div>
      <div class="flex justify-between items-center px-5 py-3">
        <button
          phx-click={toggle_side_menu()}
          class="bg-black rounded-full text-sm px-3 py-1 bg-gradient-to-tl from-primary-500 to-secondary-500 bg-size-200 bg-pos-0 text-white uppercase flex items-center"
        >
          <img src="/images/icons/menu-outline.svg" class="h-6" />
          <span class="ml-1" :if="event">#{{ event.code }}</span>
        </button>

        <div class="inline-flex justify-between items-center text-white text-sm">
          <img src="/images/icons/online-users.svg" class="h-6 mr-2" />
          <span id="counter" phx-update="ignore" phx-hook="UpdateAttendees">
            {{ attendeesNb }}
          </span>
        </div>
      </div>
    </div>

    <div
      class="flex flex-col space-y-4 px-5 pt-20 pb-32 lg:w-1/3 bg-black min-h-screen"
      id="post-list"
    >
      
    </div>


    <div
      id="reacts"
      class="fixed right-5 bottom-12 z-30 w-1/3"
    >
    </div>


    <div class="fixed w-full bottom-12">
      <form
            id="post-form"
            class="w-full lg:w-1/3 lg:mx-auto"
          >
            <div
              class="rounded-lg text-base px-3 py-2 mx-5 relative"
              style="
              background: rgb(17,134,213);
              background: linear-gradient(333deg, rgba(17,134,213,0.4962359943977591) 0%, rgba(163,39,255,0.5046393557422969) 100%);
              box-shadow: 0 4px 30px rgba(0, 0, 0, 0.1);
              backdrop-filter: blur(11.5px);
              -webkit-backdrop-filter: blur(11.5px);"
            >
              <div class="ml-0">
                <a
                  href="#"
                  class="px-2 py-0.5 text-xs text-white rounded-full w-fit bg-gray-900 flex gap-x-1 items-center"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="w-4 h-4"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                    />
                  </svg>
                  <span v-if="nickname === ''">Anonymous</span>
                  <span v-else>{{ nickname }}</span>
                </a>
              </div>

              <button class="absolute right-5 top-6 opacity-50" id="submitBtn">
                <img src="/images/icons/send.svg" class="h-6" />
              </button>

              <div class="flex space-x-2 items-center">
                <textarea
                  id="postFormTA"
                  class="bg-transparent outline-none w-full text-white h-10 placeholder-white pt-3 resize-none pr-20 leading-4 overflow-y-hidden focus:overflow-y-auto"
                  placeholder="Ask, comment..."
                />
          </div>
        </div>
        <button type="submit" phx-disable-with="Saving..." id="hiddenSubmit" class="hidden">Save</button>
      </form>

    </div>

    <div
      class="flex space-x-6 fixed justify-center bottom-3 w-full lg:w-1/3 lg:mx-auto"
    >
      <a
        
        id="react-heart"
        class="cursor-pointer"
      >
        <img class="h-6" src="/images/icons/heart.svg" />
      </a>

      <a
        id="react-clap"
        class="cursor-pointer"
      >
        <img class="h-6" src="/images/icons/clap.svg" />
      </a>

      <a
        id="react-hundred"
        class="cursor-pointer"
      >
        <img class="h-6" src="/images/icons/hundred.svg" />
      </a>

      <a
        id="react-raisehand"
        class="cursor-pointer"
      >
        <img class="h-6" src="/images/icons/raisehand.svg" />
      </a>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { Socket, Presence } from "phoenix";

const nickname = ref("");
const socket = ref(null);
const channel = ref(null);
const presence = ref(null);
const attendeesNb = ref(1);
const eventUuid = ref("");
const event = ref({
  name: "",
  code: ""
});

const sideMenu = ref(false);

onMounted(() => {
  eventUuid.value = window.eventUuid;
  event.value = window.mEvent;
  console.log(event.value);

  connectToRoom();

  channel.value.on("post_created", handleNewMessage);
});

const connectToRoom = () => {
  let csrf_token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
  socket.value = new Socket("/socket", {params: {_csrf_token: csrf_token}});

  socket.value.connect();

  channel.value = socket.value.channel(`event:${eventUuid.value}`, {});
  presence.value = new Presence(channel.value);

  presence.value.onSync(() => {
    presence.value.list((id, {metas: [first, ...rest]}) => {
      attendeesNb.value = rest.length + 1;
    })
  })

  channel.value.join();
}

const handleNewMessage = (payload) => {
  console.log("new message");
  console.log(payload);
};

</script>
