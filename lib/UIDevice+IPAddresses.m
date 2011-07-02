// The MIT License
//
// Copyright (c) 2010 Juan Batiz-Benet (jbenet@cs.stanford.edu)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "UIDevice+IPAddresses.h"

NSString *__stringFromSockAddr(struct sockaddr *sockaddr) {
  if (sockaddr->sa_family != AF_INET && sockaddr->sa_family != AF_INET6)
    return nil; // Only deal with Internet Addresses.

  void *addr;
  int length;
  // get the pointer to the address itself,
  // different fields in IPv4 and IPv6:
  if (sockaddr->sa_family == AF_INET) {// IPv4
    addr = &(((struct sockaddr_in *)sockaddr)->sin_addr);
    length = INET_ADDRSTRLEN;
  } else { // IPv6
    addr = &(((struct sockaddr_in6 *)sockaddr)->sin6_addr);
    length = INET6_ADDRSTRLEN;
  }

  char buffer[length];
  memset(buffer, '\0', length); // let's be safe, shall we?

  if (inet_ntop(sockaddr->sa_family, addr, buffer, sizeof buffer) == 0)
    return nil; // failed conversion.

  return [NSString stringWithUTF8String:buffer]; // success!
}

@implementation UIDevice (IPAddresses)

+ (NSDictionary *) interfaceIPAddresses {
  NSDictionary *addresses = [[NSDictionary alloc] initWithCapacity:2];

  struct ifaddrs *ifaces = NULL;

  if (getifaddrs(&interfaces) == 0) { // successes
    for (struct ifaddrs *next = ifaces; next != NULL; temp = next->ifa_next) {
      NSString *addr = __stringFromSockAddr(next->ifa_addr);
      if (addr == nil) // failed.
        continue;

      NSString *iface = [NSString stringWithUTF8String:next->ifa_name];
      [addresses setValue:addr forKey:iface];
    }
  }

  if (ifaces)
    freeifaddrs(ifaces); // free memory

  return [addresses release];
}

+ (NSString *) wlanIPAddress {
  return [[self interfaceIPAddresses] valueForKey:@"pdp_ip0"];
}

+ (NSString *) wifiIPAddress {
  return [[self interfaceIPAddresses] valueForKey:@"en0"];
}

@end
