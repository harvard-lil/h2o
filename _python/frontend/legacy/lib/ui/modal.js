import Component from './component';

function restrictFocus (e) {
  if (!this.el.contains(e.target)) {
    e.stopPropagation();
    this.el.focus();
  }
}

export default class ModalComponent extends Component {
  constructor (id, trigger, customEvents) {
    super({
      id: id,
      events: Object.assign(customEvents || {}, {
        'click .close': () => { this.destroy() },
        'click .cancel': () => { this.destroy() },
        [`click #${id}`]: (e) => { if (e.target.id === id) this.destroy() },
        [`keydown #${id}`]: (e) => { if (e.key=='Escape'||e.key=='Esc'||e.keyCode==27) this.destroy()}
      })
    });
    this.id = id;
    this.trigger = trigger;
    this.handleFocus = restrictFocus.bind(this);

    // DOM
    document.body.insertBefore(this.el, document.body.firstChild);
    this.render();
    this.el.focus();
    document.querySelector('.modal-overlay').classList.add('open');
    document.getElementById('non-modal').setAttribute('aria-hidden', 'true');
    document.addEventListener('focus', this.handleFocus, true);
  }

  destroy () {
    if ( this.el.dataset.processing !== "true") {
      document.removeEventListener('focus', this.handleFocus, true);
      document.getElementById('non-modal').removeAttribute('aria-hidden');
      document.querySelector('.modal-overlay').classList.remove('open');
      this.trigger.focus();
      super.destroy();
    }
  }
}
