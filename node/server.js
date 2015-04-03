var nsq = require('nsqjs'),
  reader = new nsq.Reader('input', 'nsqjs', {
    nsqdTCPAddresses: 'nsqd:4150'
  }),
  writer = new nsq.Writer('nsqd', 4150);

reader.connect();
writer.connect();

reader.on('closed', function () {
  console.log('Reader closed');
});

writer.on('closed', function () {
  console.log('Writer closed');
});

reader.on('message', function (msg) {
  console.log('Received message [%s]: %s', msg.id, msg.body.toString());
  writer.publish('chat', encodeURI(msg.body.toString()));
  msg.finish();
});
