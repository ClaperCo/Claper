const RoomFeed = {
  mounted() {
    this.chip = document.querySelector(this.el.dataset.chip);
    this.unread = 0;
    this.atBottom = true;
    this.onScroll = () => {
      this.atBottom = this.distanceFromBottom() <= 48;
      if (this.atBottom) this.clearUnread();
    };
    this.onChipClick = () => this.scrollToBottom(true);
    this.onMessageSent = () => {
      this.sentMessage = true;
      this.scrollToBottom(true);
      clearTimeout(this.sentMessageTimeout);
      this.sentMessageTimeout = setTimeout(() => {
        this.sentMessage = false;
      }, 1000);
    };
    this.el.addEventListener("scroll", this.onScroll, { passive: true });
    this.el.addEventListener("room:message-sent", this.onMessageSent);
    this.chip?.addEventListener("click", this.onChipClick);
    requestAnimationFrame(() => this.scrollToBottom(true));
  },
  beforeUpdate() {
    this.wasAtBottom = this.distanceFromBottom() <= 48;
    this.previousPostCount = this.postCount();
  },
  updated() {
    const newPostCount = this.postCount();
    const hasNewPost = newPostCount > this.previousPostCount;

    if (hasNewPost && this.sentMessage) {
      clearTimeout(this.sentMessageTimeout);
      this.sentMessage = false;
      requestAnimationFrame(() => this.scrollToBottom(true));
    } else if (hasNewPost && this.wasAtBottom) {
      this.scrollToBottom();
    } else if (hasNewPost) {
      this.unread += newPostCount - this.previousPostCount;
      this.showUnread();
    }
  },
  destroyed() {
    this.el.removeEventListener("scroll", this.onScroll);
    this.el.removeEventListener("room:message-sent", this.onMessageSent);
    this.chip?.removeEventListener("click", this.onChipClick);
    clearTimeout(this.sentMessageTimeout);
  },
  postCount() {
    return this.el.querySelectorAll(":scope > [id^='posts-']").length;
  },
  distanceFromBottom() {
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight;
  },
  scrollToBottom(instant = false) {
    this.el.scrollTo({
      top: this.el.scrollHeight,
      behavior: instant ? "auto" : "smooth",
    });
    this.atBottom = true;
    this.clearUnread();
  },
  showUnread() {
    if (!this.chip) return;
    const count = this.chip.querySelector("[data-unread-count]");
    if (count) count.textContent = this.unread;
    this.chip.classList.remove("hidden");
  },
  clearUnread() {
    this.unread = 0;
    this.chip?.classList.add("hidden");
  },
};

export default RoomFeed;
