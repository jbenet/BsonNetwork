#!/usr/bin/env python

import sys
import socket
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
  try:
    d = str(bson.loads(data))
    print d[0:1000]
    running_data = ''
  except Exception, e:
    print 'partial data:', running_data


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
