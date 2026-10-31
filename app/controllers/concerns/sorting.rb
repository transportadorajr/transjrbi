module Sorting
  private

  def apply_sort(relation, *default, except: [], **default_columns)
    fallback = relation.order(*default, **default_columns)
    return fallback if !relation.sortable_column?(params[:sort]) || except.include?(params[:sort].to_s)

    relation.sorted_by(params[:sort], params[:direction]).order(*default, **default_columns)
  end
end
