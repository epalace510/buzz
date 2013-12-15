# for more details see: http://emberjs.com/guides/models/defining-models/

Buzz.Episode = DS.Model.extend
  title: DS.attr 'string'
  link_url: DS.attr 'string'
  description: DS.attr 'string'
  audio_url: DS.attr 'string'
  publication_date: DS.attr 'date'
  podcast: DS.belongsTo 'Buzz.Podcast', async: true
