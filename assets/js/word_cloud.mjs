import { createWordCloud } from "@claperco/wordcloud.js";

// Every word arrives with the server's match key as id. The library would
// otherwise call crypto.randomUUID, which browsers leave out on plain HTTP,
// and self-hosted instances are often reached that way.
function readWords(el) {
  return JSON.parse(el.dataset.words);
}

// add() is the only way to get the library's highlight, but it cannot take
// an id, so it is used just for words that are already shown and were sent
// again. Anything else replaces the whole set.
function onlyCountsGrew(current, next) {
  return (
    next.length === current.size &&
    next.every(({ id, name, count }) => {
      const word = current.get(id);
      return word && word.name === name && word.count <= count;
    })
  );
}

const WordCloud = {
  mounted() {
    this.cloud = createWordCloud(this.el, readWords(this.el), {
      textColor: this.el.dataset.textColor || null,
    });
  },

  updated() {
    const next = readWords(this.el);
    const current = new Map(this.cloud.getWords().map((word) => [word.id, word]));

    if (!onlyCountsGrew(current, next)) {
      this.cloud.setWords(next);
      return;
    }

    for (const { id, name, count } of next) {
      const added = count - current.get(id).count;
      if (added > 0) this.cloud.add(name, added);
    }
  },

  destroyed() {
    this.cloud.destroy();
  },
};

export default WordCloud;
