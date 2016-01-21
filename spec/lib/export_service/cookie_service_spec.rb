require 'export_service/cookie_service'

module ExportService

  RSpec.describe CookieService do

    describe '#forwarded_cookies_hash' do
      let(:base_params) do
        {
          '_h2o_session' => 'abc123==',
          'export_format' => 'doc',
        }
      end

      it 'is a no-op pass-through for known but untranslated cookies' do
        params = base_params.merge({
            'fontface' => 'fontfaceVAL',
            'fontsize' => 'fontsizeVAL',
            'fontface_mapped' => 'fontface_mappedVAL',
            'fontsize_mapped' => 'fontsize_mappedVAL',
            'margin-top' => 'margin-topVAL',
            'margin-right' => 'margin-rightVAL',
            'margin-bottom' => 'margin-bottomVAL',
            'margin-left' => 'margin-leftVAL',
          })
        expect(
          described_class.forwarded_cookies_hash(params)
          ).to eq({
            '_h2o_session' => 'abc123==',
            'export_format' => 'doc',
            'print_font_face' => 'fontfaceVAL',
            'print_font_size' => 'fontsizeVAL',
            'print_font_face_mapped' => 'fontface_mappedVAL',
            'print_font_size_mapped' => 'fontsize_mappedVAL',
            'print_margin_top' => 'margin-topVAL',
            'print_margin_right' => 'margin-rightVAL',
            'print_margin_bottom' => 'margin-bottomVAL',
            'print_margin_left' => 'margin-leftVAL',
          })
      end

      it 'maps default yes/show values to cookie values' do
        params = base_params.merge({
            'printtitle' => 'yes',
            'printparagraphnumbers' => 'yes',
            'printannotations' => 'yes',
            'printlinks' => 'yes',
            'hiddentext' => 'show',
            'printhighlights' => 'all',
            'toc_levels' => '2',
          })
        expect(
          described_class.forwarded_cookies_hash(params)
          ).to eq({
            '_h2o_session' => 'abc123==',
            'export_format' => 'doc',
            'print_titles' => 'true',
            'print_paragraph_numbers' => 'true',
            'print_annotations' => 'true',
            'print_links' => 'true',
            'hidden_text_display' => 'true',
            'print_highlights' => 'all',
            'toc_levels' => '2',
          })
      end

      it 'maps non-default no/hide values to cookie values' do
        params = base_params.merge({
            'printtitle' => 'no',
            'printparagraphnumbers' => 'no',
            'printannotations' => 'no',
            'printlinks' => 'no',
            'hiddentext' => 'hide',
            'printhighlights' => 'all',
            'toc_levels' => '2',
          })
        expect(
          described_class.forwarded_cookies_hash(params)
          ).to eq({
            '_h2o_session' => 'abc123==',
            'export_format' => 'doc',
            'print_titles' => 'false',
            'print_paragraph_numbers' => 'false',
            'print_annotations' => 'false',
            'print_links' => 'false',
            'hidden_text_display' => 'false',
            'print_highlights' => 'all',
            'toc_levels' => '2',
          })
      end

      it 'handles a mix of all happy path scenarios' do
        params = base_params.merge({
            'fontface' => 'fontfaceVAL',
            'fontsize' => 'fontsizeVAL',
            'printtitle' => 'yes',
            'printparagraphnumbers' => 'yes',
            'printannotations' => 'no',
            'printlinks' => 'no',
          })
        expect(
          described_class.forwarded_cookies_hash(params)
          ).to eq({
            '_h2o_session' => 'abc123==',
            'export_format' => 'doc',
            'print_font_face' => 'fontfaceVAL',
            'print_font_size' => 'fontsizeVAL',
            'print_titles' => 'true',
            'print_paragraph_numbers' => 'true',
            'print_annotations' => 'false',
            'print_links' => 'false',
          })
      end

      describe 'special cases' do
        it 'drops params with no corresponding cookie' do
          params = base_params.merge({
              'someignoredparam' => 'ignoredvalue',
            })
          expect(
            described_class.forwarded_cookies_hash(params)
            ).to eq({
              '_h2o_session' => 'abc123==',
              'export_format' => 'doc',
            })
        end

        it 'complains when it cannot find mapped value for a mapped field' do
          fake_rails = double('rails').as_null_object
          stub_const('Rails', fake_rails)
          expect(fake_rails).to receive(:logger)

          params = base_params.merge({
              'printtitle' => 'bad value',
            })
          expect(
            described_class.forwarded_cookies_hash(params)
            ).to eq({
              '_h2o_session' => 'abc123==',
              'export_format' => 'doc',
            })
        end

      end

    end

  end

end
