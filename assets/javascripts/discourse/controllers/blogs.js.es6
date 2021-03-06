export default Em.Controller.extend({
  loading: false,

  loadMore() {
    var model = this.get("model");

    if (model.get('allLoaded')) { return Ember.RSVP.resolve(); }

    return Discourse.ajax('/blogs.json?offset=' + model.length).then(function(data){
      if (data.length === 0) {
        model.set("allLoaded", true);
      }
      model.addObjects(_.map(data, function(topic) {
        return Discourse.Topic.create(topic);
      }));
    });
  }
});
