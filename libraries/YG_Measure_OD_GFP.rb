# By: Eriberto Lopez
# elopez3@uw.edu
# 10/01/18

module YG_Measure_OD_GFP
    
    def transfer_cultures(in_item, out_item) 
        
        if debug
            in_item = Item.find(276614) # Contains new part_associations 100118
        end
        
        in_collection = Collection.find(in_item.id)
        out_collection = Collection.find(out_item.id)
        
        rc_list = in_collection.get_non_empty
        
        vol_display_matrix = get_vol_transfer_matrix(in_collection)
        log_info 'vol_display_matrix', vol_display_matrix
        show do
           title "Transfer Culture Aliquots to #{out_item.object_type.name} for Plate Reader" 
           separator
           check "Grab a clean <b>#{out_item.object_type.name}</b>."
           check "Label the #{out_item.object_type.name} => <b>#{out_item.id}</b>."
           check "Use a multi-channel pipettor to transfer the correct volume from <b>#{in_item.id}</b> to the <b>#{out_item.object_type.name}</b>."
           note "<b>Follow the table below to transfer the correct volume:</b>"
           table highlight_alpha_rc(in_item, rc_list) {|r,c| "#{vol_display_matrix[r][c]}µl"}
        end
        positive_sytox_rc = get_pos_sytox_rc(in_collection)
        show do 
            title "Adding Ethanol to Positive SYTOX Control"
            separator
            check "Get #{150*positive_sytox_rc.length}µl of 100% EtOH"
            bullet "Mix throughly by pipetting"
            note "<b>Follow the table below to add 150ul of EtOH to the correct well</b>"
            table highlight_alpha_rc(in_item, positive_sytox_rc){|r,c| "150µl"}
        end
        
        # Ensure that collection sample matricies get transferred
        in_coll_matrix = in_collection.matrix
        out_collection.matrix = in_coll_matrix
        out_collection.save
    end
    
    def get_vol_transfer_matrix(in_collection)
        vol_display_matrix = Array.new(in_collection.object_type.rows) { Array.new(in_collection.object_type.columns) {-1}}
        rc_list = in_collection.get_non_empty
        rc_list.each {|r,c|
            control_check = in_collection.get_part_data(:control, r, c)
            if control_check == 'negative_sytox'
                vol_display_matrix[r][c] = 150
            else
                vol_display_matrix[r][c] = 300
            end
            
        }
        return vol_display_matrix
        # Old part_data association matrix - 100118
        # vol_display_matrix = input_part_data_matrix.each_with_index.map {|row, r_idx| 
        #     row.each_with_index.map {|part_data_obj, c_idx|
        #         # ie: part_data_obj => {"source"=>[{"id"=>291209, "row"=>0, "column"=>0, "process"=>"dilution"}], "od600"=>0.0003}
        #         obj_keys = part_data_obj.keys
        #         if !obj_keys.empty?
        #             if obj_keys.include? 'control'
        #                 (part_data_obj[:control] == 'negative_sytox') ? trans_vol = 150 : trans_vol = 300
        #             else
        #                 trans_vol = 300
        #             end
        #         else
        #             trans_vol = -1
        #         end
        #         trans_vol
        #     }
        # }
    end
    def get_pos_sytox_rc(in_collection)
        positive_sytox_rc = []
        rc_list = in_collection.get_non_empty
        rc_list.each {|r,c|
            control_check = in_collection.get_part_data(:control, r, c)
            if control_check == 'negative_sytox'
                positive_sytox_rc.push([r,c])
            end
        }
        # Old part_data association matrix - 100118
        # vol_display_matrix = input_part_data_matrix.each_with_index.map {|row, r_idx| 
        #     row.each_with_index.map {|part_data_obj, c_idx|
        #         # ie: part_data_obj => {"source"=>[{"id"=>291209, "row"=>0, "column"=>0, "process"=>"dilution"}], "od600"=>0.0003}
        #         obj_keys = part_data_obj.keys
        #         if !obj_keys.empty?
        #             if obj_keys.include? 'control'
        #                 (part_data_obj[:control] == 'positive_sytox') ? positive_sytox_rc.push([r_idx, c_idx]) : nil
        #             end
        #         end
        #     }
        # }
        return positive_sytox_rc
    end
    
    def get_timepoint(op, tpoint_param)
        return op.input(tpoint_param).val.to_i
    end
    
    def get_media_type(in_item)
        media = in_item.get('type_of_media')
        media = media.nil? ? 'SC' : media
        return media
    end


end # Module YG_Measure_OD_GFP