import delegate from 'delegate';
import morphdom from 'morphdom';

export default class Component {
  constructor ({id, events}) {
    if (id) {
      this.el = this.findOrCreateElement(id);
    }
    if (events) {
      for (let eventName in events) { this.bindEvent(eventName, events[eventName]); }
    }
  }

  bindEvent (eventNames, callback) {
    eventNames = eventNames.split(/, ?/g);
    for (let eventName of eventNames) {
      let [event, ...selector] = eventName.split(' ');
      this.addEventDelegate(selector.join(' '), event, callback);
    }
  }

  render () {
    if (!this.el) { return; }
    morphdom(this.el, this.template().toString());
  }

  findOrCreateElement(id) {
    let el = document.querySelector(`#${id}`);
    if (el) { return el; }
    el = document.createElement('div');
    el.id = id;
    return el;
  }

  addEventDelegate (selector, eventName, callback, useCapture = false) {
    this.eventDelegates = this.eventDelegates || [];
    this.eventDelegates.push(delegate(this.el, selector, eventName, callback, useCapture));
  }

  destroy () {
    if ( this.el.dataset.processing !== "true") {
      this.el.parentElement && this.el.parentElement.removeChild(this.el);
      for (let eventDelegate of this.eventDelegates) { eventDelegate.destroy() }
    }
  }
}
