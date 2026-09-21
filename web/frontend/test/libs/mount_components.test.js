import { componentApps } from '../../libs/mount_components';
import { h } from 'vue';

it('mounts JSON props without compiling server text or component attribute values', () => {
  document.body.innerHTML = '<div id="app"><p>{{ dangerous() }}</p><synthetic-widget :value="&quot;{{ dangerous() }}&quot;"></synthetic-widget></div>';
  window.dangerous = vi.fn();
  const mounts = componentApps(document.querySelector('#app'), {
    'synthetic-widget': {props: ['value'], render() { return h('span', this.value); }},
  });
  mounts.forEach(({app, element}) => app.mount(element));
  expect(document.querySelector('p').textContent).toBe('{{ dangerous() }}');
  expect(document.querySelector('span').textContent).toBe('{{ dangerous() }}');
  expect(window.dangerous).not.toHaveBeenCalled();
  mounts.forEach(({app}) => app.unmount());
  delete window.dangerous;
});

it('rejects expressions in bound props rather than evaluating them', () => {
  document.body.innerHTML = '<div id="app"><synthetic-widget :value="window.dangerous()"></synthetic-widget></div>';
  expect(() => componentApps(document.querySelector('#app'), {'synthetic-widget': {}})).toThrow(SyntaxError);
});
