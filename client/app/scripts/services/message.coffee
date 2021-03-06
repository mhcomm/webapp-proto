'use strict'

###*
 # @ngdoc function
 # @name webappProtoApp.controller:AboutCtrl
 # @description
 # # AboutCtrl
 # Controller of the webappProtoApp
###

###
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus. Sed sit amet ipsum mauris. Maecenas congue ligula ac quam viverra nec consectetur ante hendrerit. Donec et mollis dolor. Praesent et diam eget libero egestas mattis sit amet vitae augue. Nam tincidunt congue enim, ut porta lorem lacinia consectetur. Donec ut libero sed arcu vehicula ultricies a non tortor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean ut gravida lorem. Ut turpis felis, pulvinar a semper sed, adipiscing id dolor. Pellentesque auctor nisi id magna consequat sagittis. Curabitur dapibus enim sit amet elit pharetra tincidunt feugiat nisl imperdiet. Ut convallis libero in urna ultrices accumsan. Donec sed odio eros. Donec viverra mi quis quam pulvinar at malesuada arcu rhoncus. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. In rutrum accumsan ultricies. Mauris vitae nisi at sem facilisis semper ac in est.


Vivamus fermentum semper porta. Nunc diam velit, adipiscing ut tristique vitae, sagittis vel odio. Maecenas convallis ullamcorper ultricies. Curabitur ornare, ligula semper consectetur sagittis, nisi diam iaculis velit, id fringilla sem nunc vel mi. Nam dictum, odio nec pretium volutpat, arcu ante placerat erat, non tristique elit urna et turpis. Quisque mi metus, ornare sit amet fermentum et, tincidunt et orci. Fusce eget orci a orci congue vestibulum. Ut dolor diam, elementum et vestibulum eu, porttitor vel elit. Curabitur venenatis pulvinar tellus gravida ornare. Sed et erat faucibus nunc euismod ultricies ut id justo. Nullam cursus suscipit nisi, et ultrices justo sodales nec. Fusce venenatis facilisis lectus ac semper. Aliquam at massa ipsum. Quisque bibendum purus convallis nulla ultrices ultricies. Nullam aliquam, mi eu aliquam tincidunt, purus velit laoreet tortor, viverra pretium nisi quam vitae mi. Fusce vel volutpat elit. Nam sagittis nisi dui.
###


angular.module('webappProtoApp')
  .factory('messageLocal', ($localStorage) ->

    messages = []
    if !$localStorage.messages?
      $localStorage.messages = []
    else
       messages = $localStorage.messages

    return {
      newMessage: (content, user) ->
        mess = {
          timestamp: new Date()
          author: user.id
          content: content
        }
        $localStorage.messages.push(mess)
    }
  )
  .factory('messageSrv', ($resource, CONF) ->
    ress = $resource(CONF.server + '/api/messages/:_id/')
    return ress
  )
  .factory('restMessage', ($resource, CONF) ->
    ress = $resource(CONF.server + '/api/messages/:_id/')
    return {
      query: ress.query
      get: ress.get
      save: ress.save
      new: (data) ->
        return new ress(data)

    }
  )
  .factory('syncMessage', ['$resource', '$q', '$localStorage', 'restMessage', 'connectionStatus', '$timeout', '$rootScope', 'NotifSvc', ($resource, $q, $localStorage, restMessage, connectionStatus, $timeout, $rootScope, NotifSvc) ->
    ### Synced message resource TBD ###

    resourceName = 'messages'
    queueName = '_tx' + resourceName
    feched = '_fetched' + resourceName

    if !$localStorage[feched]?
      $localStorage[feched] = false

    # Add tx queue if necessary
    if !$localStorage[queueName]?
      $localStorage[queueName] = []

    if !$localStorage[resourceName]?
      $localStorage[resourceName] = []


    class Message
      constructor: (data) ->
        # Do construction
        console.log('Create new message')
        @timestamp = new Date()
        angular.extend(this, data)
      $save: () ->
        return syncResource.save(this)


    syncResource = {
      isOnline: connectionStatus.isOnline()
      sync: () ->
        if $localStorage[queueName]
          console.log("Tx: " + $localStorage[queueName].length + " elem(s) to sync.")

          for message in $localStorage[resourceName]
            if message.uid in $localStorage[queueName]
              restMessage.new(message).$save().then(
                (value)->
                  message.needSync = false
                  $localStorage[queueName].splice($localStorage[queueName].indexOf(value.uid), 1)
                (response)->
                  console.log("error: ", response)
              )

      fetch: () ->
        # TODO limit qte of elt fetched by filtering with date
        return restMessage.query().$promise.then (srv_messages) ->
          msg_uid_list = (message.uid for message in $localStorage[resourceName])
          $localStorage[resourceName] = srv_messages
          $localStorage[resourceName].sort (f,s) ->
            a = new Date(f.timestamp)
            b = new Date(s.timestamp)
            return a>b ? 1 : (a<b ? -1 : 0)
          $localStorage[resourceName].reverse()

          # TODO differential update
          ###for srv_msg in srv_messages
            if srv_msg.uid not in msg_uid_list
              $localStorage[ressName].push(srv_msg)
          for uid in msg_uid_list###

          #$rootScope.$broadcast('messagesUpdated')

      query: (query) ->
        console.log('Query message list')
        defered = $q.defer()

        # Initial fetch
        if not $localStorage[feched]
            $localStorage[feched] = true
            syncResource.fetch()

        defered.resolve($localStorage[resourceName])
        return {$promise: defered.promise}

      save: (mess) ->
        console.log('Save message')

        defered = $q.defer()
        mess.needSync = true

        # Add message to localstorage
        $localStorage[resourceName].push(mess)
        $localStorage[resourceName].sort (f,s) ->
          a = new Date(f.timestamp)
          b = new Date(s.timestamp)
          return a>b ? 1 : a<b ? -1 : 0
        $localStorage[resourceName].reverse()

        console.log($localStorage[resourceName])

        ### Add message uid to tx table ###
        $localStorage[queueName].push(mess.uid)

        # Immediat sync if online
        if @isOnline
          @sync()

        defered.resolve(mess)

        return defered.promise

      get: (query) ->
        return null
      new: (data) ->
        return new Message(data)

      getData: () ->
        return $localStorage[resourceName]

    }

    connectionStatus.$on 'online', () ->
      # Check if there is message in TX to send
      syncResource.isOnline = true
      syncResource.sync()

    connectionStatus.$on 'offline', () ->
      syncResource.isOnline = false

    poller = () ->
      if syncResource.isOnline
        console.log("Sync message resource")
        syncResource.sync()
        #syncResource.fetch()
      $timeout(poller, 5000)

    poller()

    return syncResource
  ])
