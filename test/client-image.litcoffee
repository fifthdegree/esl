    import test from 'ava'
    import { once } from 'node:events'
    import { FreeSwitchClient } from 'esl'
    import { start, stop } from './utils.mjs'

    second = 1000
    sleep = (timeout) -> new Promise (resolve) -> setTimeout resolve, timeout; return

We start two FreeSwitch docker.io instances, one is used as the "client" (and is basically our SIP test runner), while the other one is the "server" (and is used to test the `server` side of the package).

    client_port = 8024

    await start()
    await sleep 2*second

    test 'should be reachable', (t) ->
      client = new FreeSwitchClient port: client_port
      p = once client, 'connect'
      client.connect()
      await p
      await client.end()
      t.pass()
      return

    test 'should report @once errors', (t) ->
      client = new FreeSwitchClient port: client_port
      p = once client, 'connect'
      client.connect()
      [ call ] = await p
      failure = await call
        .send 'catchme'
        .then (-> no), (-> yes)
      await client.end()
      if failure
        t.pass()
      else
        t.fail()
      return

    ###
    test 'should detect and report login errors', (t) ->
      await new Promise (resolve,reject) ->
        client = new FreeSwitchClient port: client_port, password: 'barfood'
        client.on 'connect',
          reject new Error 'Should not reach here'
        client.on 'error', (error) ->
          resolve error
        client.connect()
        return
      t.pass()
      return
    ###

    test 'should reloadxml', (t) ->
      await new Promise (resolve) ->
        client = new FreeSwitchClient port: client_port
        cmd = 'reloadxml'
        client.on 'connect', (call) ->
          res = await call.api cmd
          t.regex res.body, /\+OK \[Success\]/
          await client.end()
          resolve()
        client.connect()
        return
      t.pass()
      return

    test 'should properly parse events', (t) ->

      t.log 'Should properly parse plain events'
      await new Promise (resolve,reject) ->
        client = new FreeSwitchClient port: client_port
        client.on 'connect', (call) ->
          try

            res = await call.send 'event plain ALL'
            t.regex res.headers['Reply-Text'], /\+OK event listener enabled plain/

            msg = call.onceAsync 'CUSTOM'
            await call.sendevent 'foo', 'Event-Name':'CUSTOM', 'Event-XBar':'some'
            msg = await msg

            t.like msg.body, {
              'Event-Name': 'CUSTOM'
              'Event-XBar': 'some'
            }

            await call.exit()
            await client.end()
            resolve()
          catch error
            reject error
          return
        client.connect()
        return

      t.log 'Should properly parse JSON events'
      await new Promise (resolve,reject) ->
        client = new FreeSwitchClient port: client_port
        client.on 'connect', (call) ->
          try

            res = await call.send 'event json ALL'
            t.regex res.headers['Reply-Text'], /\+OK event listener enabled json/

            msg = call.onceAsync 'CUSTOM'
            await call.sendevent 'foo', 'Event-Name':'CUSTOM', 'Event-XBar':'ë°ñ'
            msg = await msg

            t.like msg.body, {
              'Event-Name': 'CUSTOM'
              'Event-XBar': 'ë°ñ'
            }

            await call.exit()
            await client.end()
            resolve()
          catch error
            reject error
          return
        client.connect()
        return

      t.pass()
      return

    test.skip 'should detect failed socket', (t) ->

      t.timeout 1000

      await new Promise (resolve,reject) ->
        client = new FreeSwitchClient port: client_port
        client.on 'connect', (call) ->
          try
            error = await call
              .api "originate sofia/test-client/sip:server-failed@127.0.0.1:34564 &park"
              .catch (error) -> error

FIXME currently return CHAN_NOT_IMPLEMENTED

            t.regex error.args.reply, /^-ERR NORMAL_TEMPORARY_FAILURE/
            await client.end()
            resolve()
          catch error
            reject error

        client.connect()
        return
      t.pass()
      return

    test 'should stop', (t) ->
      await stop()
      t.pass()