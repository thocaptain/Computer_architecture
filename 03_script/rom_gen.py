import csv

dont_care_val = '\'0'

input_signal  = []
output_signal = []
input_x  = []
input_w = []
output_x  = []
output_w = []
input_inst_val_list = []
output_inst_val_list = []
inst_name_list = []

with open('RV32i_ROM.csv', 'r') as file:
    csvfile = csv.reader(file)

    input_offset  = None
    output_offset = None
    end_offset    = None

    for r,row in enumerate(csvfile):
        if r==0: # INPUT/OUTPUT
            input_offset  = row.index('INPUT')
            output_offset = row.index('OUTPUT')
        elif r==1: # FIELD NAME
            end_offset = row.index('')
            input_signal.extend(row[input_offset:output_offset])
            output_signal.extend(row[output_offset:end_offset])
        elif r==2: # DONT CARE VALUE
            input_x.extend(row[input_offset:output_offset])
            output_x.extend(row[output_offset:end_offset])
        elif r==3: # BIT_WIDTH
            input_w.extend(row[input_offset:output_offset])
            output_w.extend(row[output_offset:end_offset])
        elif row[0]: # REPLACE * with doncare value, add bitwidth before value
            asterisk_free_in  = [(input_x[v] if val=='*' else val) for v,val in enumerate(row[input_offset:output_offset])]
            asterisk_free_out = []

            for v, val in enumerate(row[output_offset:end_offset]):
                width_concat = output_w[v]+'\'b' if output_x[v][0].isnumeric() else ''
                print(output_x[v], width_concat)
                if val=='*':
                    asterisk_free_out.append(width_concat+output_x[v])
                else:
                    asterisk_free_out.append(width_concat+val)

            input_inst_val_list.append(asterisk_free_in)
            output_inst_val_list.append(asterisk_free_out)
            inst_name_list.append(row[0])
            print(asterisk_free_in)
            print(asterisk_free_out)

output_control = 'out_ctrl'
input_sig_concat = '{' + ','.join(input_signal) + '}'
print(input_sig_concat)
total_input_width = sum([int(w) for w in input_w])
print(total_input_width)

print('===============================================================================================================================')
print('localparam OUT_W = ', '{' + '+'.join(output_w) + '};')
print('===============================================================================================================================')
print('    casez({})'.format(input_sig_concat))
# cmt_sig_list = '// '+ ','.join(f'{c :8}' for c in output_signal)
# print(cmt_sig_list)
for i in range(len(input_inst_val_list)):
    case_item_string = '        ' + str(total_input_width) +'\'b'+''.join(input_inst_val_list[i]) + ': begin'
    cmt_string = ' // {}'.format(inst_name_list[i])
    print(case_item_string+cmt_string)
    statement_string = '{' + ','.join(f'{c :8}' for c in output_inst_val_list[i]) + '};'
    statement_string = '            ' + output_control + ' = ' + statement_string
    print(statement_string)
    print('            o_inst_vld = 1\'b1;')
    print('        end')

print('        default: begin // invalid command')
print('            {}=\'0;'.format(output_control))
print('            o_inst_vld = 1\'b0;')
print('        end')
print('    endcase')

output_control_assign = '    {' + ','.join(output_signal) + '}' + ' = {};'.format(output_control)
print(output_control_assign)

print('===============================================================================================================================')
