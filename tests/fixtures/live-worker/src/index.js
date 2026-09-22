export default {
  async fetch() {
    return new Response("SMOKE_VERSION=placeholder\n", {
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
};
