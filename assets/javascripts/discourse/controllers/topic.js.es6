import TopicController from 'discourse/controllers/topic';

export default TopicController.reopen({
  replyPosts: Ember.computed('model.postStream.posts', function() {
    return _.rest(this.get('model.postStream.posts'));
  }),

  replyAsNewTopicVisible: Em.computed.notEmpty('controllers.quote-button.buffer'),

  postStreamChanged: Ember.observer('model.postStream.posts.@each', function() {
    var replies = _.rest(this.get('model.postStream.posts'));
    var existingPosts = this.get('replyPosts');

    existingPosts.pushObjects(_.difference(replies, this.get('replyPosts')));
    existingPosts.removeObjects(_.difference(existingPosts, replies));
  }),

  hasReplyPosts: Ember.computed('model.postStream.posts.@each', function() {
    return this.get('model.postStream.posts.length') > 1;
  }),

  actions: {
    makeToc: function() {
      this.get('content').makeToc();
    },

    replyAsNewTopic: function () {
      this._super(this.get('controllers.quote-button.post'));
    },

    makeHowto: function() {
      this.get('content').makeHowto();
    },

    makeSection: function() {
      this.get('content').makeSection();
    },

    makeBlog: function() {
      this.get('content').makeBlog();
    },

    makeDefaultArchetype: function() {
      this.get('content').makeDefaultArchetype();
    },
  }
});
