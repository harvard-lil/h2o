import ModalComponent from 'legacy/lib/ui/modal';
import delegate from 'delegate';
import {html} from 'es6-string-html-template';

delegate(document, '[data-action="show-casebook-modal"]', 'click', (e) => showCasebookModal(e));

function showCasebookModal (e) {
  new NewCasebookModal('new-casebook-modal', e.target);
}

class NewCasebookModal extends ModalComponent {
  template () {
    return html`<div class="modal fade in" id="${this.id}" style="display: block"  tabindex="-1" aria-labelledby="${this.id}-title">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <button type="button" class="close" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            <h4 id="${this.id}-title" class="modal-title">Create a Casebook</h4>
          </div>
          <div class="modal-body">
            Would you like to make a new casebook from scratch or search for a casebook you can copy and customize?

            <div class="modal-button-container">
            <div class="modal-button-box" >
              <a href="/casebooks/new">
                <svg width="87" height="87" viewBox="0 0 86 86" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <g filter="url(#filter0_d_46_2101)">
                  <path d="M80.308 39C80.308 59.9952 63.4414 77 42.654 77C21.8667 77 5 59.9952 5 39C5 18.0048 21.8667 1 42.654 1C63.4414 1 80.308 18.0048 80.308 39Z" fill="#0DAF02" stroke="#0DAF02" stroke-width="2"/>
                  <path d="M43.0003 21.9818V57.4647" stroke="white" stroke-width="3" stroke-linecap="square"/>
                  <path d="M25.2734 39.7092H60.7563" stroke="white" stroke-width="3" stroke-linecap="square"/>
                  </g>
                  <defs>
                  <filter id="filter0_d_46_2101" x="0" y="0" width="86" height="86" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
                  <feFlood flood-opacity="0" result="BackgroundImageFix"/>
                  <feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>
                  <feOffset dy="4"/>
                  <feGaussianBlur stdDeviation="2"/>
                  <feComposite in2="hardAlpha" operator="out"/>
                  <feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/>
                  <feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_46_2101"/>
                  <feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_46_2101" result="shape"/>
                  </filter>
                  </defs>
                </svg>
                
                <p class="modal-button-caption">
                 Make a New Casebook
                </p>
                
              </a>
            </div>

          <div class="modal-button-box">
          <a href="/search">
            <svg width="95" height="95" viewBox="0 0 95 95" fill="none" xmlns="http://www.w3.org/2000/svg">
              <g filter="url(#filter0_d_100_2456)">
              <path d="M85.308 43C85.308 63.9952 68.4414 81 47.654 81C26.8667 81 10 63.9952 10 43C10 22.0048 26.8667 5 47.654 5C68.4414 5 85.308 22.0048 85.308 43Z" fill="#4874D1" stroke="#4874D1" stroke-width="2"/>
              </g>
              <g filter="url(#filter1_d_100_2456)">
              <path d="M49.7263 34.9794L57.2872 42.5404L44.0834 55.7442L33.4715 58.6663L36.3936 48.0544L53.9786 30.4694C54.2445 30.3031 55.0217 29.8796 56.0622 29.8186C57.1004 29.7576 58.612 30.0405 60.3547 31.7832C62.0973 33.5258 62.3802 35.0374 62.3192 36.0757C62.2582 37.1161 61.8347 37.8933 61.6684 38.1592L59.8505 39.9771L52.2895 32.4162L49.7263 34.9794ZM54.0123 30.4357C54.0123 30.4357 54.0121 30.4359 54.0116 30.4364L54.0118 30.4362C54.0122 30.4359 54.0123 30.4357 54.0123 30.4357ZM61.7016 38.126L61.7014 38.1262C61.7023 38.1253 61.7024 38.1252 61.7016 38.126Z" stroke="white" stroke-width="3.625"/>
              </g>
              <defs>
              <filter id="filter0_d_100_2456" x="5" y="4" width="86" height="86" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
              <feFlood flood-opacity="0" result="BackgroundImageFix"/>
              <feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>
              <feOffset dy="4"/>
              <feGaussianBlur stdDeviation="2"/>
              <feComposite in2="hardAlpha" operator="out"/>
              <feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/>
              <feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_100_2456"/>
              <feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_100_2456" result="shape"/>
              </filter>
              <filter id="filter1_d_100_2456" x="0" y="0" width="95" height="95" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
              <feFlood flood-opacity="0" result="BackgroundImageFix"/>
              <feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>
              <feOffset dy="4"/>
              <feGaussianBlur stdDeviation="2"/>
              <feComposite in2="hardAlpha" operator="out"/>
              <feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/>
              <feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_100_2456"/>
              <feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_100_2456" result="shape"/>
              </filter>
              </defs>
            </svg>
            
            <p class="modal-button-caption">
            Customize a Casebook
            </p>
            
          </a>
          </div>
          </div>
          <div class="modal-footer">


          </div>

          
          </div>
        </div>
      </div>
    </div>`
  }
}
