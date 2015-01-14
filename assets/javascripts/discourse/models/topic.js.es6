function changeArchetype(model, archetype) {
  return Discourse.ajax(
    '/t/' + model.get('id') + '/archetype',
    { type: 'PUT', data: { id: archetype } }
  ).then(function () { model.set('archetype', archetype); });
}

export default Discourse.Topic.reopen({
  isBook: Em.computed.equal('archetype', 'book'),
  isPart: Em.computed.equal('archetype', 'part'),

  makeBook: function () {
    changeArchetype(this, 'book');
  },

  makePart: function() {
    changeArchetype(this, 'part');
  },

  makeDefaultArchetype: function () {
    var self = this;

    return Discourse.ajax(
      '/t/' + this.get('id') + '/archetype',
      { type: 'DELETE' }
    ).then(function () { self.set('archetype', 'regular'); });
  }
});
