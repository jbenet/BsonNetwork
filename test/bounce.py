#!/usr/bin/env python

import sys
import socket
import struct
import bson

def setupListenSocket(port):
  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  s.bind(('localhost', port))
  s.listen(1)
  return s

running_data = ''
def outputBSON(data):
  global running_data
  running_data += data
  if len(running_data) < 4:
    return

  length = struct.unpack('<i', running_data[:4])[0]
  if len(running_data) < length:
    return;

  print length

  d = str(bson.loads(running_data[:length]))
  print length, 'bytes: ', d[0:1000]
  running_data = running_data[length:]


def bounceConnection(conn):
  while 1:
    data = conn.recv(1024)
    if not data: break
    conn.send(data)
    outputBSON(data)


def runBouncer(port):
  s = setupListenSocket(port)
  print 'listening on port',port
  while True:
    try:
      conn, addr = s.accept()
      print addr,'connected.'

      bounceConnection(conn)

      print addr,'disconnected.'
      conn.close()
    except socket.error, e:
      print addr,'error (',e,')'


def main():
  print 'socket bouncer'
  if len(sys.argv) == 2:
    runBouncer(int(sys.argv[1]))
  else:
    print 'usage: ', sys.argv[0], 'listen_port'

if __name__ == '__main__':
  main()
