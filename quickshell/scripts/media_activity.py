"""Keep media cards in most recently started playback order."""


class MediaRecency:
    def __init__(self):
        self.records = {}
        self.sequence = 0

    @staticmethod
    def track(player):
        return (player.get('url', ''), player.get('title', ''), player.get('artist', ''))

    def arrange(self, players, preferred_url=''):
        first_poll = not self.records
        previous = self.records
        records = {}
        activated = []
        for player in players:
            identity = player['id']
            track = self.track(player)
            playing = bool(player.get('playing'))
            old = previous.get(identity)
            rank = old['rank'] if old else 0
            records[identity] = dict(track=track, playing=playing, rank=rank)
            if not first_poll and playing and (not old or not old['playing'] or old['track'] != track):
                activated.append(identity)

        # Firefox's shared endpoint identifies its last controlled media tab.
        # This seeds the browser order on startup and resolves simultaneous
        # browser transitions observed in the same polling interval.
        preferred = next((p['id'] for p in players if preferred_url and p.get('url') == preferred_url), None)
        if first_poll and players:
            activated = [preferred or next((p['id'] for p in players if p.get('playing')), players[0]['id'])]
        elif preferred in activated:
            activated.remove(preferred)
            activated.append(preferred)
        for identity in activated:
            self.sequence += 1
            records[identity]['rank'] = self.sequence
        self.records = records
        return sorted(players, key=lambda p: -records[p['id']]['rank'])
