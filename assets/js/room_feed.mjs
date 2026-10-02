const RoomFeed = {
  mounted() {
    this.chip = document.querySelector(this.el.dataset.chip);
    this.unread = 0;
    this.atBottom = true;
    this.lastScrollTop = this.el.scrollTop;
    // A smooth scroll to a new post passes through positions far from the
    // bottom, so only a move up means the reader stopped following.
    this.onScroll = () => {
      const scrollTop = this.el.scrollTop;
      if (this.distanceFromBottom() <= 48) {
        this.atBottom = true;
        this.clearUnread();
      } else if (scrollTop < this.lastScrollTop) {
        this.atBottom = false;
      }
      this.lastScrollTop = scrollTop;
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
    // The feed shrinks without a scroll event when the focus slot or the
    // captions take space from it.
    this.resizeObserver = new ResizeObserver(() => {
      this.followIfNearBottom();
      if (this.atBottom) this.scrollToBottom(true);
    });
    this.resizeObserver.observe(this.el);
    requestAnimationFrame(() => this.scrollToBottom(true));
  },
  beforeUpdate() {
    this.followIfNearBottom();
    this.previousPostCount = this.postCount();
    this.previousScrollHeight = this.el.scrollHeight;
  },
  updated() {
    const newPostCount = this.postCount();
    const hasNewPost = newPostCount > this.previousPostCount;
    const feedGrew = this.el.scrollHeight > this.previousScrollHeight;

    if (hasNewPost && this.sentMessage) {
      clearTimeout(this.sentMessageTimeout);
      this.sentMessage = false;
      requestAnimationFrame(() => this.scrollToBottom(true));
    } else if (this.atBottom && (hasNewPost || feedGrew)) {
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
    this.resizeObserver.disconnect();
    clearTimeout(this.sentMessageTimeout);
  },
  postCount() {
    return this.el.querySelectorAll(":scope > [id^='posts-']").length;
  },
  // The feed can bring the reader back to the bottom without a scroll event,
  // for example when the focus slot collapses.
  followIfNearBottom() {
    if (this.distanceFromBottom() <= 48) this.atBottom = true;
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
