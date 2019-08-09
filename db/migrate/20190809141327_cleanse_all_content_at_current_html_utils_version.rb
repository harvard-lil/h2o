class CleanseAllContentAtCurrentHtmlUtilsVersion < ActiveRecord::Migration[5.2]
  ANNOTATABLES = [Case, TextBlock]

  def up
    ANNOTATABLES.each do |klass|
      klass.find_each do |instance|
        new_content = HTMLUtils.cleanse(instance.content)
        if instance.content != new_content
          # use update_column to avoid touching the timestamps
          instance.update_column :content, new_content
        end
      end
    end
  end

  def down
    ANNOTATABLES.each do |klass|
      # Apply HTML cleansing / munging to existing content attributes
      klass.find_each do |instance|
        # if the case was annotated, use the HTMLUtils version that was in place at the point
	    # that the first annotation was created, maxing out at V3 because V4 onward was only used
	    # when formatting HTML for exports. If it's not annotated, use the newest HTMLUtils
	    date = instance.annotated? ?
	             [instance.annotations.order(created_at: :asc).limit(1).pluck(:created_at)[0],
	              HTMLUtils::V3::EFFECTIVE_DATE].min :
	             Date.today
        new_content = HTMLUtils.at(date).cleanse(instance.raw_content.content)

        if instance.content != new_content
          # use update_column to avoid touching the timestamps
          instance.update_column :content, new_content
        end
      end
    end
  end
end
