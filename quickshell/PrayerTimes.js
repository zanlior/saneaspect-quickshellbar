.pragma library

function selection(data, epoch) {
    const days = data.days || [];
    const today = days.find(d => epoch >= d.startEpoch && epoch < d.endEpoch);
    const upcoming = days.reduce((events, day) => events.concat(day.prayers), []).filter(p => p.epoch >= epoch).sort((a, b) => a.epoch - b.epoch);
    const next = upcoming.length ? upcoming[0] : null;
    const passed = today ? days.filter(d => d.endEpoch >= today.startEpoch && d.startEpoch <= epoch)
        .reduce((events, day) => events.concat(day.prayers), []).filter(p => p.epoch <= epoch).sort((a, b) => b.epoch - a.epoch) : [];
    const previous = passed.length ? passed[0] : null;
    const orbitDay = today && today.prayers.some(p => p.epoch >= epoch) ? today : days.find(d => d.prayers.some(p => p.epoch >= epoch));
    return {next: next, previous: previous, cards: orbitDay ? orbitDay.prayers : [], hijriDate: today ? today.hijriDate : '',
            tomorrow: !!next && !!today && next.epoch >= today.endEpoch};
}

function elapsedLabel(seconds) {
    const minutes = Math.floor(Math.max(0, seconds) / 60);
    if (minutes === 0) return 'Just now';
    if (minutes < 60) return minutes + 'm ago';
    const hours = Math.floor(minutes / 60);
    return hours + 'h' + (minutes % 60 ? ' ' + minutes % 60 + 'm' : '') + ' ago';
}

function countdown(seconds) {
    const total = Math.max(0, Math.floor(seconds));
    const pad = n => ('0' + n).slice(-2);
    return {main: pad(Math.floor(total / 3600)) + ':' + pad(Math.floor(total % 3600 / 60)), seconds: pad(total % 60)};
}

function timeLabel(time, clock24) {
    if (clock24) return time;
    const parts = time.split(':');
    const hour = Number(parts[0]);
    return (hour % 12 || 12) + ':' + parts[1] + (hour >= 12 ? ' PM' : ' AM');
}
