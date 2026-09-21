import { createApp, h } from 'vue';

// Server-rendered text must never become a Vue template. Only these precompiled
// components are mounted; bound attributes are JSON data, never expressions.
export function componentProps(element) {
  const props = {};
  for (const {name, value} of element.attributes) {
    const bound = name.startsWith(':');
    const key = (bound ? name.slice(1) : name).replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
    if (bound) {
      if (value !== '') props[key] = JSON.parse(value);
    } else if (!name.startsWith('v-') && !name.startsWith('@') && !name.startsWith('on')) {
      props[key] = value;
    }
  }
  return props;
}

export function componentApps(root, components) {
  return Object.entries(components).flatMap(([tag, component]) =>
    [...root.querySelectorAll(tag)].map(element => {
      const props = componentProps(element);
      const app = createApp({render: () => h(component, props)});
      return {app, element};
    })
  );
}
