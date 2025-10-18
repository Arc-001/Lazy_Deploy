# Lazy Deploy

---

## Into

These are just a internal set of scripts that I use to deploy my projects for testing...
Note that these are far far away from the standards of a production ready deployment system.

## Why?

As I use OCI for deploying my projects from a VPS(yes, I don't use vercel or render because I like knowing everything about my deployment environment), I often encounter the problem of:

## How?

- FIREWALLS: this is the most painful problem I had to solve as OCI has 2 firewalls, one from the VCN and other one is managed using IPTABLES which are hard to maintain.
    - Solution... purge iptables, and use ufw :)
- HTTPS setup: setting up SSL certificates
    - Solution: scripted certbot

- Cool Container Ideas?
    - Solution: I Commit either compose.yml here

---